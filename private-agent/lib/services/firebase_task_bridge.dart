import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/agent_action.dart';
import 'action_handler.dart';
import 'agent_identity_service.dart';
import 'ai_service.dart';

/// Claims Beatrice Voice tasks from the paired agent queue and publishes
/// progress without coupling task execution to the WebView lifecycle.
class FirebaseTaskBridge {
  FirebaseTaskBridge({
    required this.aiService,
    required this.actionHandler,
    AgentIdentityService? identityService,
  }) : _identityService = identityService ?? AgentIdentityService();

  final AiService aiService;
  final ActionHandler actionHandler;
  final AgentIdentityService _identityService;
  StreamSubscription<DatabaseEvent>? _subscription;
  late DatabaseReference _tasks;
  String? _pairedOwnerUid;

  /// The canonical agent id. Prefer reading from the identity service; this
  /// is kept for callers that need a synchronous snapshot.
  String? get agentId => _identityService.currentIdentity?.agentId;

  Future<void> init() async {
    final identity = await _identityService.getIdentity();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }

    // If the mobile user is signed in, treat them as the owner. This is the
    // authoritative identity; web sessions become authorized participants,
    // not owners.
    final mobileOwnerUid = auth.currentUser?.uid;
    if (mobileOwnerUid != null && mobileOwnerUid.isNotEmpty) {
      _pairedOwnerUid = mobileOwnerUid;
      if (identity.ownerUid != mobileOwnerUid) {
        await _identityService.setOwner(mobileOwnerUid);
      }
    } else {
      _pairedOwnerUid = identity.ownerUid;
    }

    _tasks = FirebaseDatabase.instance.ref('deviceTasks/${identity.agentId}');
    _subscription = _tasks.onChildAdded.listen(
      _onTaskAdded,
      onError: (Object error) {
        developer.log(
          'Firebase task bridge listener failed: $error',
          name: 'BeatriceOS',
        );
      },
    );

    await _identityService.touch();
  }

  /// Stores the Beatrice Voice account currently paired through the trusted
  /// in-app WebView. Tasks from any other Firebase account are ignored.
  Future<void> pairWithOwner(String ownerUid) async {
    if (ownerUid.trim().isEmpty) return;
    _pairedOwnerUid = ownerUid;
    await _identityService.setOwner(ownerUid);
  }

  Future<void> _onTaskAdded(DatabaseEvent event) async {
    final value = event.snapshot.value;
    if (value is! Map) return;
    final task = Map<String, dynamic>.from(value);
    if (task['status'] != 'incoming') return;

    final ownerUid = task['ownerUid'] as String?;
    if (_pairedOwnerUid == null || ownerUid != _pairedOwnerUid) {
      developer.log(
        'Ignoring task that does not belong to the paired Beatrice account.',
        name: 'BeatriceOS',
      );
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

    final goal = task['goal'] as String?;
    if (goal == null || goal.trim().isEmpty) {
      await taskRef.update({
        'status': 'failed',
        'error': 'Task goal is missing.',
      });
      return;
    }

    await taskRef.update({
      'status': 'running',
      'startedAt': ServerValue.timestamp,
    });

    try {
      final result = await actionHandler.execute(
        AgentAction(
          action: 'execute_task',
          params: {'goal': goal},
          response: goal,
        ),
        aiService: aiService,
        onProgress: (message) {
          taskRef.child('events').push().set({
            'type': 'progress',
            'message': message,
            'at': ServerValue.timestamp,
          });
          taskRef.update({
            'statusMessage': message,
            'updatedAt': ServerValue.timestamp,
          });
        },
      );
      await taskRef.update({
        'status': result.success ? 'done' : 'failed',
        'summary': result.details,
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
