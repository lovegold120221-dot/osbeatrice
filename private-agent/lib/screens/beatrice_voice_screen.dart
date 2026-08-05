import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/agent_action.dart';
import '../services/action_handler.dart';
import '../services/ai_service.dart';

/// Hosts the deployed Beatrice Voice experience while keeping device control
/// inside private-agent. The web app may request high-level goals only; Android
/// automation remains exclusively behind [ActionHandler].
class BeatriceVoiceScreen extends StatefulWidget {
  const BeatriceVoiceScreen({
    super.key,
    required this.aiService,
    required this.actionHandler,
    required this.deviceId,
  });

  final AiService aiService;
  final ActionHandler actionHandler;
  final String? deviceId;

  @override
  State<BeatriceVoiceScreen> createState() => _BeatriceVoiceScreenState();
}

class _BeatriceVoiceScreenState extends State<BeatriceVoiceScreen> {
  static final Uri _beatriceUri = Uri.parse('https://beatrice.eburon.ai');
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final params = AndroidWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
      const PlatformWebViewControllerCreationParams(),
    );
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'BeatriceBridge',
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _loadError = null;
              });
            }
            if (widget.deviceId != null) {
              _emitEvent({'type': 'device.ready', 'deviceId': widget.deviceId});
            }
          },
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? false) && mounted) {
              setState(() {
                _isLoading = false;
                _loadError = error.description;
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            // Keep the embedded experience constrained to Beatrice itself.
            if (uri != null && uri.scheme == 'https' && uri.host == _beatriceUri.host) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(_beatriceUri);

    final androidController = _controller.platform;
    if (androidController is AndroidWebViewController) {
      androidController.setOnPlatformPermissionRequest((request) {
        // RECORD_AUDIO has already been granted to this Android app during
        // onboarding. Only the trusted Beatrice HTTPS origin is allowed to
        // navigate in this WebView, so pass microphone requests through.
        request.grant();
      });
    }
  }

  Future<void> _onBridgeMessage(JavaScriptMessage message) async {
    Map<String, dynamic> request;
    try {
      request = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      await _emitEvent({'type': 'task.error', 'error': 'Invalid bridge message.'});
      return;
    }

    if (request['type'] == 'task.cancel') {
      widget.actionHandler.cancelTask();
      await _emitEvent({'type': 'task.cancelled', 'id': request['id']});
      return;
    }

    if (request['type'] != 'task.create') return;
    final id = request['id'] as String?;
    final goal = request['goal'] as String?;
    if (id == null || id.isEmpty || goal == null || goal.trim().isEmpty) {
      await _emitEvent({
        'type': 'task.error',
        'id': id,
        'error': 'A task id and goal are required.',
      });
      return;
    }

    // Do not await this from the WebView callback. The voice conversation stays
    // live while the executor works and receives progress/result events.
    await _emitEvent({'type': 'task.accepted', 'id': id});
    _runTask(id, goal.trim());
  }

  Future<void> _runTask(String id, String goal) async {
    try {
      final result = await widget.actionHandler.execute(
        AgentAction(action: 'execute_task', params: {'goal': goal}, response: goal),
        aiService: widget.aiService,
        onProgress: (message) => _emitEvent({
          'type': 'task.progress',
          'id': id,
          'message': message,
        }),
      );
      await _emitEvent({
        'type': result.success ? 'task.result' : 'task.error',
        'id': id,
        'summary': result.details,
      });
    } catch (error) {
      await _emitEvent({'type': 'task.error', 'id': id, 'error': '$error'});
    }
  }

  Future<void> _emitEvent(Map<String, dynamic> event) {
    final payload = jsonEncode(event);
    return _controller.runJavaScript(
      'window.dispatchEvent(new CustomEvent("beatrice-task-event", {detail: $payload}));',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_loadError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Beatrice Voice could not be loaded.\n$_loadError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
