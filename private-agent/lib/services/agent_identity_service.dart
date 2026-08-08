import 'dart:convert';
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_identity.dart';

/// Manages the canonical install-scoped agent identity.
///
/// Existing devices that already have `firebase_task_device_id` in
/// SharedPreferences keep that value as their `agentId`. New installs get a
/// cryptographically random UUID.
class AgentIdentityService {
  static const String _legacyDeviceIdKey = 'firebase_task_device_id';
  static const String _identityKey = 'beatrice_agent_identity_v2';

  AgentIdentity? _identity;

  /// Loads or creates the canonical agent identity.
  Future<AgentIdentity> getIdentity() async {
    if (_identity != null) return _identity!;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_identityKey);
    if (stored != null && stored.isNotEmpty) {
      try {
        final decoded = jsonDecode(stored) as Map<String, dynamic>;
        _identity = AgentIdentity.fromJson(decoded);
        return _identity!;
      } catch (e) {
        // Fall through to recreate.
      }
    }

    // Migration: honor the legacy device id so installed devices keep their
    // stable identifier and do not lose pairing/history.
    String agentId;
    final legacyDeviceId = prefs.getString(_legacyDeviceIdKey);
    if (legacyDeviceId != null && legacyDeviceId.isNotEmpty) {
      agentId = legacyDeviceId;
    } else {
      agentId = _generateAgentId();
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final identity = AgentIdentity(
      agentId: agentId,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      protocolVersion: AgentIdentity.currentProtocolVersion,
      skillManifestVersion: '0',
      createdAt: DateTime.now(),
    );

    await _persist(identity);
    _identity = identity;
    return identity;
  }

  /// Returns the current identity without loading if it has been loaded.
  AgentIdentity? get currentIdentity => _identity;

  /// Updates the owner UID after a successful pairing handshake.
  Future<AgentIdentity> setOwner(String ownerUid) async {
    final identity = await getIdentity();
    final updated = identity.copyWith(ownerUid: ownerUid);
    await _persist(updated);
    _identity = updated;
    return updated;
  }

  /// Bumps lastSeenAt without changing owner.
  Future<AgentIdentity> touch() async {
    final identity = await getIdentity();
    final updated = identity.copyWith(lastSeenAt: DateTime.now());
    await _persist(updated);
    _identity = updated;
    return updated;
  }

  Future<void> _persist(AgentIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_identityKey, identity.toRawJson());
  }

  String _generateAgentId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // RFC 4122 v4 UUID format.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'agent-${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
