import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/agent_identity.dart';
import '../models/device_profile.dart';
import '../services/agent_identity_service.dart';
import '../services/ai_service.dart';
import '../services/agent_state_service.dart';
import '../services/device_profile_service.dart';

/// Hosts the deployed Beatrice Voice experience while keeping device control
/// inside private-agent. The web app may request high-level goals only; Android
/// automation remains exclusively behind [ActionHandler] and the shared
/// Firebase task queue.
///
/// Bridge protocol:
///   Web     -> Flutter: device.handshake.request, device.handshake.ack,
///                       device.webSession, task.cancel,
///                       agent.identity.get, agent.capabilities.get, agent.status.get
///   Flutter -> Web    : device.handshake.response, agent.bound, agent.identity,
///                       agent.capabilities, agent.status
///
/// All skill execution is written to the shared `deviceTasks/{agentId}` queue;
/// the direct WebView task.create path has been removed.
class BeatriceVoiceScreen extends StatefulWidget {
  const BeatriceVoiceScreen({
    super.key,
    required this.aiService,
  });

  final AiService aiService;

  @override
  State<BeatriceVoiceScreen> createState() => _BeatriceVoiceScreenState();
}

class _BeatriceVoiceScreenState extends State<BeatriceVoiceScreen> {
  static final Uri _beatriceUri = Uri.parse('https://osbeatrice.vercel.app/');
  static const Set<String> _trustedAuthHosts = {
    'osbeatrice.vercel.app',
    'beatrice-os.firebaseapp.com',
    'accounts.google.com',
  };
  static const Duration _handshakeRetryInterval = Duration(seconds: 1);
  static const Duration _handshakeRetryMax = Duration(seconds: 30);

  final AgentIdentityService _identityService = AgentIdentityService();
  final DeviceProfileService _profileService = DeviceProfileService();
  final AgentStateService _agentStateService = AgentStateService();
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _loadError;
  AgentIdentity? _identity;
  DeviceProfile? _profile;

  // Handshake state
  String? _pendingWebSessionUid;
  String? _acknowledgedWebSessionUid;
  Timer? _handshakeRetryTimer;
  DateTime? _handshakeStartedAt;

  @override
  void initState() {
    super.initState();
    _initIdentityAndProfile();

    final params =
        AndroidWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
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
            // Google/Firebase authentication uses a short redirect chain. Keep
            // it inside the embedded screen, but do not allow arbitrary links.
            if (uri != null &&
                uri.scheme == 'https' &&
                _trustedAuthHosts.contains(uri.host)) {
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

  Future<void> _initIdentityAndProfile() async {
    _identity = await _identityService.getIdentity();
    _profile = await _profileService.getProfile();
  }

  void _startHandshakeRetry(String webSessionUid) {
    _stopHandshakeRetry();
    _handshakeStartedAt ??= DateTime.now();
    _handshakeRetryTimer = Timer.periodic(_handshakeRetryInterval, (_) async {
      if (_acknowledgedWebSessionUid == webSessionUid) {
        _stopHandshakeRetry();
        return;
      }
      final elapsed = DateTime.now().difference(_handshakeStartedAt!);
      if (elapsed > _handshakeRetryMax) {
        _stopHandshakeRetry();
        developerLog('Handshake retry timeout for webSession $webSessionUid');
        return;
      }
      await _sendHandshakeResponse(webSessionUid);
    });
  }

  void _stopHandshakeRetry() {
    _handshakeRetryTimer?.cancel();
    _handshakeRetryTimer = null;
  }

  Future<void> _sendHandshakeResponse(String webSessionUid) async {
    if (_identity == null) {
      await _initIdentityAndProfile();
    }
    if (_identity == null) return;
    final user = FirebaseAuth.instance.currentUser;
    await _emitEvent('device.handshake.response', {
      'agentId': _identity!.agentId,
      'ownerUid': user?.uid,
      'webSessionUid': webSessionUid,
      'email': user?.email,
      'displayName': user?.displayName,
      'protocolVersion': AgentIdentity.currentProtocolVersion,
    });
  }

  Future<void> _onBridgeMessage(JavaScriptMessage message) async {
    Map<String, dynamic>? request;
    try {
      request = jsonDecode(message.message) as Map<String, dynamic>?;
    } catch (e) {
      developerLog('Invalid bridge message: ${message.message}');
      return;
    }
    if (request == null) return;

    final type = request['type'] as String?;
    final user = FirebaseAuth.instance.currentUser;

    if (type == 'device.handshake.request') {
      final webSessionUid = request['webSessionUid'] as String?;
      if (webSessionUid == null || webSessionUid.isEmpty) return;
      _pendingWebSessionUid = webSessionUid;
      _acknowledgedWebSessionUid = null;
      _handshakeStartedAt = DateTime.now();
      await _sendHandshakeResponse(webSessionUid);
      _startHandshakeRetry(webSessionUid);
      return;
    }

    if (type == 'device.handshake.ack') {
      final ackSessionUid = request['webSessionUid'] as String?;
      if (ackSessionUid != null && ackSessionUid == _pendingWebSessionUid) {
        _acknowledgedWebSessionUid = ackSessionUid;
        _stopHandshakeRetry();
        developerLog('Handshake acknowledged for webSession $ackSessionUid');
      }
      return;
    }

    if (type == 'device.webSession') {
      final agentId = request['agentId'] as String?;
      final webSessionUid = request['webSessionUid'] as String?;
      if (agentId != _identity?.agentId ||
          webSessionUid == null ||
          webSessionUid.isEmpty ||
          user == null) {
        await _emitEvent('task.error', {
          'error': 'Invalid web session binding request.',
        });
        return;
      }

      final ownerUid = user.uid;
      final now = DateTime.now();
      final bindingTtl = const Duration(days: 30);
      final binding = {
        'ownerUid': ownerUid,
        'agentId': agentId,
        'createdAt': now.millisecondsSinceEpoch,
        'expiresAt': now.add(bindingTtl).millisecondsSinceEpoch,
        'protocolVersion': AgentIdentity.currentProtocolVersion,
      };

      final agentProfile = {
        'agentId': agentId,
        'ownerUid': ownerUid,
        'email': user.email,
        'displayName': user.displayName,
        'protocolVersion': AgentIdentity.currentProtocolVersion,
        'skillManifestVersion': _identity?.skillManifestVersion ?? '0',
        'appVersion': _identity?.appVersion ?? '',
        'profile': _profile?.toJson(),
        'webSessionUid': webSessionUid,
        'pairedAt': ServerValue.timestamp,
        'lastSeenAt': ServerValue.timestamp,
      };

      final pairRecord = {
        'agentId': agentId,
        'ownerUid': ownerUid,
        'pairedAt': ServerValue.timestamp,
        'lastSeenAt': ServerValue.timestamp,
      };

      final deviceRecord = {
        'agentId': agentId,
        'ownerUid': ownerUid,
        'pairedAt': ServerValue.timestamp,
        'lastSeenAt': ServerValue.timestamp,
      };

      // Atomic multi-path update: all four binding records succeed or fail together.
      await FirebaseDatabase.instance.ref().update({
        'agentProfiles/$agentId': agentProfile,
        'devicePairs/$agentId': pairRecord,
        'users/$ownerUid/devices/$agentId': deviceRecord,
        'webSessionBindings/$webSessionUid': binding,
      });

      await _identityService.setOwner(ownerUid);
      _identity = await _identityService.getIdentity();

      // Publish authoritative agent state so Beatrice can query it.
      await _agentStateService.publish();

      await _emitEvent('agent.bound', {
        'agentId': agentId,
        'ownerUid': ownerUid,
        'state': 'ready',
        'access': 'full',
      });
      return;
    }

    if (type == 'agent.identity.get') {
      await _emitEvent('agent.identity', {
        'agentId': _identity?.agentId,
        'ownerUid': _identity?.ownerUid,
        'appVersion': _identity?.appVersion,
        'protocolVersion': _identity?.protocolVersion,
        'skillManifestVersion': _identity?.skillManifestVersion,
      });
      return;
    }

    if (type == 'agent.capabilities.get') {
      await _emitEvent('agent.capabilities', _profile?.toJson() ?? {});
      return;
    }

    if (type == 'agent.status.get') {
      final state = await _agentStateService.buildState();
      await _emitEvent('agent.status', state.toJson());
      return;
    }

    // Direct task.create via WebView is intentionally not supported. All
    // execution must flow through the shared Firebase queue so history and
    // status cannot be bypassed.
    if (type == 'task.create') {
      await _emitEvent('task.error', {
        'error':
            'Direct WebView task execution is disabled. Use the Firebase skill queue.',
      });
      return;
    }
  }

  Future<void> _emitEvent(String type, Map<String, dynamic> payload) async {
    final event = Map<String, dynamic>.from(payload)..['type'] = type;
    final eventName = _eventNameForType(type);
    final js = 'window.dispatchEvent(new CustomEvent("$eventName", {detail: ${jsonEncode(event)}}));';
    return _controller.runJavaScript(js);
  }

  String _eventNameForType(String type) {
    switch (type) {
      case 'device.handshake.response':
      case 'agent.bound':
      case 'agent.identity':
      case 'agent.capabilities':
      case 'agent.status':
      case 'device.identity':
        return 'beatrice-agent-event';
      default:
        return 'beatrice-task-event';
    }
  }

  void developerLog(String message) {
    developer.log(message, name: 'BeatriceVoiceScreen');
  }

  @override
  void dispose() {
    _stopHandshakeRetry();
    super.dispose();
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
