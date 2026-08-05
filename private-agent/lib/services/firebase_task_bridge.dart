import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_action.dart';
import 'action_handler.dart';
import 'ai_service.dart';

/// Claims Beatrice Voice tasks from the paired device queue and publishes
/// progress without coupling task execution to the WebView lifecycle.
class FirebaseTaskBridge {
  FirebaseTaskBridge({required this.aiService, required this.actionHandler});

  final AiService aiService;
  final ActionHandler actionHandler;
  StreamSubscription<DatabaseEvent>? _subscription;
  late DatabaseReference _tasks;
  String? deviceId;

  Future<void> init() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString('firebase_task_device_id');
    if (deviceId == null) {
      deviceId = 'android-${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString('firebase_task_device_id', deviceId!);
    }
    _tasks = FirebaseDatabase.instance.ref('deviceTasks/$deviceId');
    _subscription = _tasks.onChildAdded.listen(_onTaskAdded, onError: (Object error) {
      developer.log('Firebase task bridge listener failed: $error', name: 'BeatriceOS');
    });
  }

  Future<void> _onTaskAdded(DatabaseEvent event) async {
    final value = event.snapshot.value;
    if (value is! Map) return;
    final task = Map<String, dynamic>.from(value);
    if (task['status'] != 'incoming') return;
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
      await taskRef.update({'status': 'failed', 'error': 'Task goal is missing.'});
      return;
    }

    await taskRef.update({'status': 'running', 'startedAt': ServerValue.timestamp});
    try {
      final result = await actionHandler.execute(
        AgentAction(action: 'execute_task', params: {'goal': goal}, response: goal),
        aiService: aiService,
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
