import 'dart:convert';

/// A structured skill invocation written by Beatrice Voice and claimed by the
/// private-agent. This replaces free-form `execute_task` goals.
class SkillInvocation {
  final String? id;
  final String ownerUid;
  final String agentId;
  final String skill;
  final int? skillVersion;
  final Map<String, dynamic> params;
  final String status;
  final String? error;
  final String? summary;
  final Map<String, dynamic>? evidence;
  final int? createdAt;
  final int? claimedAt;
  final int? startedAt;
  final int? completedAt;
  final String? executorUid;

  const SkillInvocation({
    this.id,
    required this.ownerUid,
    required this.agentId,
    required this.skill,
    this.skillVersion,
    this.params = const {},
    this.status = 'incoming',
    this.error,
    this.summary,
    this.evidence,
    this.createdAt,
    this.claimedAt,
    this.startedAt,
    this.completedAt,
    this.executorUid,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerUid': ownerUid,
        'agentId': agentId,
        'skill': skill,
        'skillVersion': skillVersion,
        'params': params,
        'status': status,
        'error': error,
        'summary': summary,
        'evidence': evidence,
        'createdAt': createdAt,
        'claimedAt': claimedAt,
        'startedAt': startedAt,
        'completedAt': completedAt,
        'executorUid': executorUid,
      };

  factory SkillInvocation.fromJson(Map<String, dynamic> json) {
    return SkillInvocation(
      id: json['id'] as String?,
      ownerUid: json['ownerUid'] as String,
      agentId: json['agentId'] as String,
      skill: json['skill'] as String,
      skillVersion: (json['skillVersion'] as num?)?.toInt(),
      params: (json['params'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {},
      status: json['status'] as String? ?? 'incoming',
      error: json['error'] as String?,
      summary: json['summary'] as String?,
      evidence: (json['evidence'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>(),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      claimedAt: (json['claimedAt'] as num?)?.toInt(),
      startedAt: (json['startedAt'] as num?)?.toInt(),
      completedAt: (json['completedAt'] as num?)?.toInt(),
      executorUid: json['executorUid'] as String?,
    );
  }

  String toRawJson() => jsonEncode(toJson());

  SkillInvocation copyWith({
    String? id,
    String? ownerUid,
    String? agentId,
    String? skill,
    int? skillVersion,
    Map<String, dynamic>? params,
    String? status,
    String? error,
    String? summary,
    Map<String, dynamic>? evidence,
    int? createdAt,
    int? claimedAt,
    int? startedAt,
    int? completedAt,
    String? executorUid,
  }) {
    return SkillInvocation(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      agentId: agentId ?? this.agentId,
      skill: skill ?? this.skill,
      skillVersion: skillVersion ?? this.skillVersion,
      params: params ?? this.params,
      status: status ?? this.status,
      error: error ?? this.error,
      summary: summary ?? this.summary,
      evidence: evidence ?? this.evidence,
      createdAt: createdAt ?? this.createdAt,
      claimedAt: claimedAt ?? this.claimedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      executorUid: executorUid ?? this.executorUid,
    );
  }
}
