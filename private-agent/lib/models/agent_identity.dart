import 'dart:convert';

/// Canonical install identity for a Beatrice OS private agent.
///
/// This is app-install identity, not hardware identity. It survives app
/// reinstalls only because it is persisted in SharedPreferences. New installs
/// get a cryptographically random UUID.
class AgentIdentity {
  /// Stable install-scoped identifier. Previously stored as
  /// `firebase_task_device_id`; new installs receive a random UUID.
  final String agentId;

  /// The Firebase UID of the owner that paired this agent.
  final String? ownerUid;

  /// App version at the time the identity was created or last seen.
  final String appVersion;

  /// Protocol version of the agent binding contract.
  static const String currentProtocolVersion = '2';
  final String protocolVersion;

  /// Version of the skill manifest this agent understands.
  final String skillManifestVersion;

  /// When the identity was first created.
  final DateTime createdAt;

  /// When the agent last checked in.
  final DateTime? lastSeenAt;

  const AgentIdentity({
    required this.agentId,
    this.ownerUid,
    required this.appVersion,
    this.protocolVersion = currentProtocolVersion,
    this.skillManifestVersion = '0',
    required this.createdAt,
    this.lastSeenAt,
  });

  AgentIdentity copyWith({
    String? agentId,
    String? ownerUid,
    String? appVersion,
    String? protocolVersion,
    String? skillManifestVersion,
    DateTime? createdAt,
    DateTime? lastSeenAt,
  }) {
    return AgentIdentity(
      agentId: agentId ?? this.agentId,
      ownerUid: ownerUid ?? this.ownerUid,
      appVersion: appVersion ?? this.appVersion,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      skillManifestVersion: skillManifestVersion ?? this.skillManifestVersion,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'agentId': agentId,
        'ownerUid': ownerUid,
        'appVersion': appVersion,
        'protocolVersion': protocolVersion,
        'skillManifestVersion': skillManifestVersion,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'lastSeenAt': lastSeenAt?.millisecondsSinceEpoch,
      };

  factory AgentIdentity.fromJson(Map<String, dynamic> json) {
    return AgentIdentity(
      agentId: json['agentId'] as String,
      ownerUid: json['ownerUid'] as String?,
      appVersion: json['appVersion'] as String? ?? '',
      protocolVersion: json['protocolVersion'] as String? ?? '1',
      skillManifestVersion: json['skillManifestVersion'] as String? ?? '0',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['lastSeenAt'] as num).toInt(),
            )
          : null,
    );
  }

  String toRawJson() => jsonEncode(toJson());
}
