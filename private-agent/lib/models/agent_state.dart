import 'dart:convert';


/// Authoritative runtime state of a bound private-agent.
///
/// This is what Beatrice Voice queries before claiming anything about device
/// access, installed apps, or available skills.
class AgentState {
  final String agentId;
  final String ownerUid;
  final String state;
  final String access;
  final AgentCapabilities capabilities;
  final Map<String, AppInfo> apps;
  final List<String> skills;
  final DateTime? updatedAt;

  const AgentState({
    required this.agentId,
    required this.ownerUid,
    this.state = 'unknown',
    this.access = 'full',
    required this.capabilities,
    required this.apps,
    required this.skills,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'agentId': agentId,
        'ownerUid': ownerUid,
        'state': state,
        'access': access,
        'capabilities': capabilities.toJson(),
        'apps': apps.map((k, v) => MapEntry(k, v.toJson())),
        'skills': skills,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  factory AgentState.fromJson(Map<String, dynamic> json) {
    return AgentState(
      agentId: json['agentId'] as String,
      ownerUid: json['ownerUid'] as String,
      state: json['state'] as String? ?? 'unknown',
      access: json['access'] as String? ?? 'full',
      capabilities: AgentCapabilities.fromJson(
        (json['capabilities'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {},
      ),
      apps: (json['apps'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>().map(
            (k, v) => MapEntry(k, AppInfo.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
      skills: (json['skills'] as List<dynamic>?)?.cast<String>().toList() ?? [],
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num).toInt())
          : null,
    );
  }

  String toRawJson() => jsonEncode(toJson());
}

class AgentCapabilities {
  final bool accessibility;
  final bool screenRead;
  final bool screenTap;
  final bool screenType;
  final bool screenSwipe;
  final bool screenSwipeWithDuration;
  final bool appLaunch;
  final bool appList;
  final bool screenshot;
  final bool shizuku;
  final bool contactsRead;
  final bool phoneCall;
  final bool smsSend;

  const AgentCapabilities({
    this.accessibility = false,
    this.screenRead = false,
    this.screenTap = false,
    this.screenType = false,
    this.screenSwipe = false,
    this.screenSwipeWithDuration = false,
    this.appLaunch = false,
    this.appList = false,
    this.screenshot = false,
    this.shizuku = false,
    this.contactsRead = false,
    this.phoneCall = false,
    this.smsSend = false,
  });

  Map<String, dynamic> toJson() => {
        'accessibility': accessibility,
        'screenRead': screenRead,
        'screenTap': screenTap,
        'screenType': screenType,
        'screenSwipe': screenSwipe,
        'screenSwipeWithDuration': screenSwipeWithDuration,
        'appLaunch': appLaunch,
        'appList': appList,
        'screenshot': screenshot,
        'shizuku': shizuku,
        'contactsRead': contactsRead,
        'phoneCall': phoneCall,
        'smsSend': smsSend,
      };

  factory AgentCapabilities.fromJson(Map<String, dynamic> json) {
    return AgentCapabilities(
      accessibility: json['accessibility'] == true,
      screenRead: json['screenRead'] == true,
      screenTap: json['screenTap'] == true,
      screenType: json['screenType'] == true,
      screenSwipe: json['screenSwipe'] == true,
      screenSwipeWithDuration: json['screenSwipeWithDuration'] == true,
      appLaunch: json['appLaunch'] == true,
      appList: json['appList'] == true,
      screenshot: json['screenshot'] == true,
      shizuku: json['shizuku'] == true,
      contactsRead: json['contactsRead'] == true,
      phoneCall: json['phoneCall'] == true,
      smsSend: json['smsSend'] == true,
    );
  }
}

class AppInfo {
  final bool installed;
  final String? packageName;
  final String? version;

  const AppInfo({
    required this.installed,
    this.packageName,
    this.version,
  });

  Map<String, dynamic> toJson() => {
        'installed': installed,
        'packageName': packageName,
        'version': version,
      };

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      installed: json['installed'] == true,
      packageName: json['packageName'] as String?,
      version: json['version'] as String?,
    );
  }
}
