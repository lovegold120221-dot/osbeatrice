import 'dart:async';

import 'action_handler.dart';
import 'ai_service.dart';
import 'app_launcher_service.dart';
import 'screen_automation_service.dart';

/// Executes the predefined whatsapp.open:v1 and whatsapp.send_message:v1
/// task-flow contracts without letting an LLM invent the navigation.
class WhatsAppSkillService {
  WhatsAppSkillService({
    required this.actionHandler,
    required this.aiService,
  })  : _launcher = AppLauncherService(),
        _screen = ScreenAutomationService();

  final ActionHandler actionHandler;
  final AiService aiService;
  final AppLauncherService _launcher;
  final ScreenAutomationService _screen;

  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Future<Map<String, dynamic>> open() async {
    _cancelled = false;
    final result = await _launcher.openApp('WhatsApp');
    if (!result.startsWith('Opened')) {
      return {'success': false, 'error': 'WHATSAPP_LAUNCH_FAILED', 'details': result};
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (_cancelled) return {'success': false, 'error': 'CANCELLED'};

    final screen = await _screen.getScreenDescription();
    final onWhatsApp = screen.toLowerCase().contains('whatsapp') ||
        screen.toLowerCase().contains('chats') ||
        screen.toLowerCase().contains('calls');

    if (!onWhatsApp) {
      return {'success': false, 'error': 'WHATSAPP_LAUNCH_FAILED', 'details': screen};
    }

    return {'success': true, 'details': 'WhatsApp is open'};
  }

  Future<Map<String, dynamic>> sendMessage({
    required String recipient,
    required String message,
    void Function(String)? onProgress,
  }) async {
    _cancelled = false;
    onProgress?.call('Opening WhatsApp...');
    final openResult = await open();
    if (!openResult['success']) return openResult;
    if (_cancelled) return {'success': false, 'error': 'CANCELLED'};

    onProgress?.call('Searching for $recipient...');
    final searchTapped = await _screen.clickByText('Search');
    if (!searchTapped) {
      // Fallback: tap the search icon area by semantic or coordinates
      await _screen.clickByText('Chats');
      await _screen.clickByText('Search');
    }
    if (_cancelled) return {'success': false, 'error': 'CANCELLED'};

    await _screen.typeText(recipient);
    await Future.delayed(const Duration(milliseconds: 500));
    if (_cancelled) return {'success': false, 'error': 'CANCELLED'};

    onProgress?.call('Selecting $recipient...');
    final selected = await _screen.clickByText(recipient);
    if (!selected) {
      return {'success': false, 'error': 'RECIPIENT_NOT_FOUND', 'details': recipient};
    }
    if (_cancelled) return {'success': false, 'error': 'CANCELLED'};

    onProgress?.call('Typing message...');
    await _screen.typeText(message);
    if (_cancelled) return {'success': false, 'error': 'CANCELLED'};

    onProgress?.call('Sending...');
    final sent = await _screen.clickByText('Send');
    if (!sent) {
      return {'success': false, 'error': 'MESSAGE_SEND_FAILED', 'details': 'Send button not found'};
    }
    if (_cancelled) return {'success': false, 'error': 'CANCELLED'};

    // Verification: wait briefly then read screen for the message text.
    await Future.delayed(const Duration(milliseconds: 600));
    final screen = await _screen.getScreenDescription();
    final verified = screen.contains(message);

    if (!verified) {
      return {'success': false, 'error': 'MESSAGE_SEND_FAILED', 'details': 'Message not visible after send'};
    }

    return {'success': true, 'details': 'Message sent to $recipient'};
  }
}
