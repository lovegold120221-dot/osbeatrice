import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_database/firebase_database.dart';

import '../models/agent_state.dart';
import '../models/device_profile.dart';
import 'agent_identity_service.dart';
import 'app_launcher_service.dart';
import 'device_profile_service.dart';
import 'skill_contracts.dart';

/// Builds and publishes the authoritative agent state that Beatrice Voice
/// queries before executing any device skill.
class AgentStateService {
  AgentStateService({
    AgentIdentityService? identityService,
    DeviceProfileService? profileService,
    AppLauncherService? appLauncher,
  })  : _identityService = identityService ?? AgentIdentityService(),
        _profileService = profileService ?? DeviceProfileService(),
        _appLauncher = appLauncher ?? AppLauncherService();

  final AgentIdentityService _identityService;
  final DeviceProfileService _profileService;
  final AppLauncherService _appLauncher;

  /// Builds the live agent state from local identity and profile.
  Future<AgentState> buildState() async {
    final identity = await _identityService.getIdentity();
    final profile = await _profileService.getProfile();

    final capabilities = _capabilitiesFromProfile(profile);
    final apps = await _detectApps(profile);
    final skills = _supportedSkills(apps);

    return AgentState(
      agentId: identity.agentId,
      ownerUid: identity.ownerUid ?? '',
      state: (identity.ownerUid != null && identity.ownerUid!.isNotEmpty) ? 'ready' : 'unbound',
      access: 'full',
      capabilities: capabilities,
      apps: apps,
      skills: skills,
      updatedAt: DateTime.now(),
    );
  }

  /// Publishes the current state to Firebase at agentState/{agentId}.
  Future<void> publish() async {
    final identity = await _identityService.getIdentity();
    if (identity.ownerUid == null || identity.ownerUid!.isEmpty) return;

    try {
      final state = await buildState();
      await FirebaseDatabase.instance
          .ref('agentState/${identity.agentId}')
          .set(state.toJson());
    } catch (e) {
      developer.log('AgentStateService.publish failed: $e', name: 'BeatriceOS');
    }
  }

  AgentCapabilities _capabilitiesFromProfile(DeviceProfile profile) {
    final cap = profile.capabilities;
    return AgentCapabilities(
      accessibility: cap.accessibilityEnabled,
      screenRead: cap.accessibilityEnabled,
      screenTap: cap.accessibilityEnabled,
      screenType: cap.accessibilityEnabled,
      screenSwipe: cap.accessibilityEnabled,
      screenSwipeWithDuration: cap.accessibilityEnabled,
      appLaunch: true,
      appList: true,
      screenshot: cap.screenshotSupported,
      shizuku: cap.shizukuPermission,
      contactsRead: true,
      phoneCall: true,
      smsSend: true,
    );
  }

  Future<Map<String, AppInfo>> _detectApps(DeviceProfile profile) async {
    // Query the launcher service for installed packages we may need to open.
    // Results are cached so subsequent state builds are cheap.
    final installedPackages = (await _appLauncher.getInstalledApps())
        .map((app) => app.packageName)
        .toSet();
    return {
      'whatsapp': AppInfo(
        installed: installedPackages.contains('com.whatsapp'),
        packageName: 'com.whatsapp',
      ),
      'whatsapp_business': AppInfo(
        installed: installedPackages.contains('com.whatsapp.w4b'),
        packageName: 'com.whatsapp.w4b',
      ),
      'telegram': AppInfo(
        installed: installedPackages.contains('org.telegram.messenger'),
        packageName: 'org.telegram.messenger',
      ),
    };
  }

  List<String> _supportedSkills(Map<String, AppInfo> apps) {
    // Authoritative list: everything the registered manifest can execute today.
    final list = SkillManifest.readyQualifiedIds.toList();
    final whatsappInstalled =
        apps['whatsapp']?.installed == true ||
        apps['whatsapp_business']?.installed == true;
    if (!whatsappInstalled) {
      list.remove('whatsapp.open:v1');
      list.remove('whatsapp.send_message:v1');
    }
    return list;
  }
}
