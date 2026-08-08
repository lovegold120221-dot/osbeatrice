import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/skill_invocation.dart';
import 'agent_identity_service.dart';
import 'agent_state_service.dart';
import 'ai_service.dart';
import 'skill_runner.dart';

/// Listens to the shared `deviceTasks/{agentId}` queue, claims structured
/// invocations, and runs them through [SkillRunner].
class SkillInvocationBridge {
  SkillInvocationBridge({
    required this.aiService,
    required this.skillRunner,
    AgentIdentityService? identityService,
    AgentStateService? agentStateService,
  })  : _identityService = identityService ?? AgentIdentityService(),
        _agentStateService = agentStateService ?? AgentStateService();

  final AiService aiService;
  final SkillRunner skillRunner;
  final AgentIdentityService _identityService;
  final AgentStateService _agentStateService;

  StreamSubscription<DatabaseEvent>? _subscription;
  String? _pairedOwnerUid;

  Future<void> init() async {
    final identity = await _identityService.getIdentity();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }

    final mobileOwnerUid = auth.currentUser?.uid;
    if (mobileOwnerUid != null && mobileOwnerUid.isNotEmpty) {
      _pairedOwnerUid = mobileOwnerUid;
      if (identity.ownerUid != mobileOwnerUid) {
        await _identityService.setOwner(mobileOwnerUid);
      }
    } else {
      _pairedOwnerUid = identity.ownerUid;
    }

    final tasks = FirebaseDatabase.instance.ref('deviceTasks/${identity.agentId}');
    _subscription = tasks.onChildAdded.listen(
      _onTaskAdded,
      onError: (Object error) {
        developer.log('SkillInvocationBridge listener failed: $error', name: 'BeatriceOS');
      },
    );

    await _agentStateService.publish();
  }

  Future<void> _onTaskAdded(DatabaseEvent event) async {
    final value = event.snapshot.value;
    if (value is! Map) return;
    final data = Map<String, dynamic>.from(value);
    if (data['status'] != 'incoming') return;

    final ownerUid = data['ownerUid'] as String?;
    if (_pairedOwnerUid == null || ownerUid != _pairedOwnerUid) {
      developer.log('Ignoring task that does not belong to the paired owner.', name: 'BeatriceOS');
      return;
    }

    final taskRef = event.snapshot.ref;
    final claim = await taskRef.runTransaction((current) {
      if (current is! Map || current['status'] != 'incoming') {
        return Transaction.abort();
      }
      final updated = Map<Object?, Object?>.from(current)
        ..['status'] = 'claimed'
        ..['claimedAt'] = ServerValue.timestamp
        ..['executorUid'] = FirebaseAuth.instance.currentUser?.uid;
      return Transaction.success(updated);
    });
    if (!claim.committed) return;

    await taskRef.update({'status': 'running', 'startedAt': ServerValue.timestamp});

    final invocation = SkillInvocation.fromJson(data);
    final resolved = invocation.copyWith(id: event.snapshot.key);

    try {
      final result = await skillRunner.run(
        resolved,
        onProgress: (message) {
          taskRef.child('events').push().set({
            'type': 'progress',
            'message': message,
            'at': ServerValue.timestamp,
          });
          taskRef.update({'statusMessage': message, 'updatedAt': ServerValue.timestamp});
        },
      );

      await taskRef.update({
        'status': result.status,
        'summary': result.summary,
        'evidence': result.evidence,
        'error': result.error,
        'completedAt': ServerValue.timestamp,
      });
    } catch (error) {
      await taskRef.update({
        'status': 'failed',
        'error': '$error',
        'completedAt': ServerValue.timestamp,
      });
    }
  }

  Future<void> dispose() async => _subscription?.cancel();
}
