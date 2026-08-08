import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:installed_apps/app_info.dart';

import '../models/skill_invocation.dart';
import 'agent_identity_service.dart';
import 'ai_service.dart';
import 'action_handler.dart';
import 'app_launcher_service.dart';
import 'screen_automation_service.dart';
import 'skill_contracts.dart';

/// Outcome of a skill flow run. Every step named in a contract's flow must
/// pass; evidence records each step so the terminal status is verifiable,
/// never guessed.
class SkillRunResult {
  final String skillId;
  final String version;
  final bool success;
  /// Terminal status: `done` on success, otherwise a failure code such as
  /// WHATSAPP_NOT_INSTALLED or WHATSAPP_RECIPIENT_NOT_FOUND.
  final String status;
  /// Per-step verification evidence.
  final List<Map<String, dynamic>> evidence;
  /// Human summary for the task queue.
  final String summary;
  /// Error detail for the task queue (null on success).
  final String? error;

  const SkillRunResult({
    required this.skillId,
    required this.version,
    required this.success,
    required this.status,
    required this.evidence,
    required this.summary,
    this.error,
  });
}

/// Executes registered task-flow contracts against the device. This is the
/// single sanctioned execution path for device skills: a contract must exist
/// before anything is tapped, typed, or launched. The agent never invents a
/// workflow — it can only run what the registry declares.
class SkillRunner {
  SkillRunner({
    required this.aiService,
    required this.actionHandler,
    AgentIdentityService? identityService,
  })  : _screenService = actionHandler.screenAutomation,
        _launcher = AppLauncherService(),
        _identityService = identityService ?? AgentIdentityService();

  final AiService aiService;
  final ActionHandler actionHandler;
  final ScreenAutomationService _screenService;
  final AppLauncherService _launcher;
  final AgentIdentityService _identityService;

  /// Entry point for [SkillInvocationBridge]: resolves the registered
  /// contract, validates gates and inputs, then executes the flow.
  Future<SkillRunResult> run(
    SkillInvocation invocation, {
    void Function(String)? onProgress,
  }) async {
    final contract = SkillManifest.find(invocation.skill);
    if (contract == null) {
      final entry = SkillManifest.findEntry(invocation.skill);
      if (entry != null && entry.soon) {
        return SkillRunResult(
          skillId: entry.id,
          version: 'v1',
          success: false,
          status: 'SKILL_NOT_READY',
          evidence: const [],
          summary: 'SKILL_NOT_READY: ${entry.qualifiedId} is registered but '
              'not yet implementable on this device.',
          error: 'Skill is catalog-registered but marked as not ready.',
        );
      }
      return SkillRunResult(
        skillId: invocation.skill,
        version: 'unknown',
        success: false,
        status: 'SKILL_NOT_FOUND',
        evidence: const [],
        summary: 'SKILL_NOT_FOUND: ${invocation.skill} is not registered.',
        error: 'Invocation references an unregistered skill.',
      );
    }

    developer.log(
      'SkillRunner executing ${contract.qualifiedId} params=${invocation.params}',
      name: 'BeatriceOS',
    );

    final gate = await _checkRequirements(contract);
    if (gate != null) {
      return _failure(contract, gate,
          '$gate — ${contract.id} requirements not met.');
    }

    final inputError = _checkInputs(contract, invocation.params);
    if (inputError != null) {
      return _failure(contract, inputError,
          'Missing required input for ${contract.id}.');
    }

    final evidence = <Map<String, dynamic>>[];
    final startMs = DateTime.now().millisecondsSinceEpoch;

    for (final step in contract.flow) {
      if (step.action == SkillFlowAction.uiWait) {
        await Future<void>.delayed(
            Duration(milliseconds: step.durationMs ?? 300));
        continue;
      }

      final passed = await _runStep(step, contract, invocation.params);
      evidence.add({'id': step.id, 'passed': passed});

      final stepLabel = step.label ?? step.id;
      if (onProgress != null) {
        onProgress('${contract.id}: $stepLabel ${passed ? 'OK' : 'failed'}');
      }

      if (!passed) {
        final code = _failureCodeFor(step.id, contract);
        return _failure(contract, code,
            '$code — failed at "$stepLabel"');
      }
    }

    final durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
    developer.log(
      'Skill ${contract.id} done in ${durationMs}ms ($evidence)',
      name: 'BeatriceOS',
    );
    return SkillRunResult(
      skillId: contract.id,
      version: contract.version,
      success: true,
      status: 'done',
      evidence: evidence,
      summary: '${contract.qualifiedId} completed in ${durationMs}ms '
          'with ${evidence.length} verified steps.',
    );
  }

  SkillRunResult _failure(SkillContract contract, String code, String why) =>
      SkillRunResult(
        skillId: contract.id,
        version: contract.version,
        success: false,
        status: code,
        evidence: const [],
        summary: why,
        error: why,
      );

  /// Verifies the agent is paired, accessibility runs, required packages are
  /// installed. Returns a failure code or null when all gates pass.
  Future<String?> _checkRequirements(SkillContract contract) async {
    final identity = await _identityService.getIdentity();
    if (contract.requirements.agentState == 'ready' &&
        (identity.ownerUid == null || identity.ownerUid!.isEmpty)) {
      return 'AGENT_NOT_PAIRED';
    }

    if (contract.requirements.accessibility) {
      final running = await _screenService.isServiceRunning();
      if (!running) return 'ACCESSIBILITY_DISABLED';
    }

    final packages = contract.requirements.package;
    if (packages != null) {
      List<AppInfo> installed;
      try {
        installed = await _launcher.getInstalledApps();
      } catch (e) {
        developer.log('Package check failed: $e', name: 'BeatriceOS');
        return contract.failureCodes['package_missing'] ?? 'PACKAGE_CHECK_FAILED';
      }
      final found = installed.any((app) => packages.matches(app.packageName));
      if (!found) {
        return contract.failureCodes['package_missing'] ??
            'PACKAGE_NOT_INSTALLED';
      }
    }
    return null;
  }

  String? _checkInputs(SkillContract contract, Map<String, dynamic> inputs) {
    for (final spec in contract.inputs) {
      if (!spec.required) continue;
      final value = inputs[spec.name];
      if (value == null || (value is String && value.trim().isEmpty)) {
        return 'INPUT_REQUIRED_MISSING:${spec.name}';
      }
    }
    return null;
  }

  Future<bool> _runStep(
    SkillStep step,
    SkillContract contract,
    Map<String, dynamic> inputs,
  ) async {
    switch (step.action) {
      case SkillFlowAction.appOpen:
        return _launchTarget(contract);
      case SkillFlowAction.uiTapText:
        final text = step.tapText ?? '';
        return text.isNotEmpty && await _screenService.clickByText(text);
      case SkillFlowAction.uiType:
        final text = _substitute(step.value ?? '', inputs);
        return text.isNotEmpty &&
            await _screenService.typeText(text, fieldHint: step.fieldHint);
      case SkillFlowAction.uiTapFirst:
        final match = _substitute(step.matchText ?? '', inputs);
        if (match.isEmpty) return false;
        if (await _screenService.clickByText(match)) return true;
        return _tapNodeContaining(match);
      case SkillFlowAction.screenInspect:
        return _inspectScreen(step);
      case SkillFlowAction.uiWait:
        await Future<void>.delayed(
            Duration(milliseconds: step.durationMs ?? 300));
        return true;
      case SkillFlowAction.generateSkill:
        return await _generateSkill(inputs);
      case SkillFlowAction.listSkills:
        return await _listSkills();
      case SkillFlowAction.updateSkill:
        return await _updateSkill(inputs);
      case SkillFlowAction.deleteSkill:
        return await _deleteSkill(inputs);
    }
  }

  /// Full-access CRUD helpers for the skill registry.
  Future<bool> _generateSkill(Map<String, dynamic> inputs) async =>
      _upsertSkill(inputs, allowCreate: true);

  Future<bool> _listSkills() async {
    try {
      developer.log('Skill registry: ${SkillManifest.qualifiedIds}', name: 'BeatriceOS');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateSkill(Map<String, dynamic> inputs) async {
    final name = inputs['skill_name']?.toString().trim() ?? '';
    if (name.isEmpty || _isBuiltIn(name)) return false;
    return _upsertSkill(inputs, allowCreate: false);
  }

  Future<bool> _deleteSkill(Map<String, dynamic> inputs) async {
    final name = inputs['skill_name']?.toString().trim() ?? '';
    if (name.isEmpty || _isBuiltIn(name)) return false;
    final removed = SkillManifest.delete(name);
    developer.log(removed ? 'Deleted skill $name' : 'Skill $name not found', name: 'BeatriceOS');
    return removed;
  }

  bool _isBuiltIn(String id) =>
      SkillManifest.isBuiltIn(id);

  Future<bool> _upsertSkill(
    Map<String, dynamic> inputs, {
    required bool allowCreate,
  }) async {
    try {
      final name = inputs['skill_name']?.toString().trim() ?? '';
      final description = inputs['description']?.toString().trim() ?? '';
      if (name.isEmpty || description.isEmpty) return false;

      final rawInputs = inputs['inputs']?.toString() ?? '[]';
      final rawFlow = inputs['flow']?.toString() ?? '[]';
      final inputList = _parseSkillInputs(rawInputs);
      final flowList = _parseSkillFlow(rawFlow);
      if (flowList.isEmpty) return false;

      final generated = SkillContract(
        id: name,
        version: 'v1',
        description: description,
        inputs: inputList,
        requirements: const SkillRequirements(),
        flow: flowList,
        successSteps: flowList.map((s) => s.id).toList(),
        failureCodes: const {
          'package_missing': 'PACKAGE_NOT_INSTALLED',
          'app_not_opened': 'APP_LAUNCH_FAILED',
        },
      );

      final existing = SkillManifest.find(name);
      if (existing != null && _isBuiltIn(name)) return false;

      if (allowCreate) {
        SkillManifest.register(generated);
      } else {
        if (existing == null) return false;
        SkillManifest.update(name, generated);
      }
      developer.log('Skill registered/updated: ${generated.qualifiedId}', name: 'BeatriceOS');
      return true;
    } catch (e) {
      developer.log('Skill upsert failed: $e', name: 'BeatriceOS');
      return false;
    }
  }

  List<SkillInputSpec> _parseSkillInputs(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((m) {
      final map = Map<String, dynamic>.from(m);
      return SkillInputSpec(
        name: map['name']?.toString() ?? 'input',
        type: map['type']?.toString() ?? 'string',
        required: map['required'] == true,
      );
    }).toList();
  }

  List<SkillStep> _parseSkillFlow(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((m) {
      final map = Map<String, dynamic>.from(m);
      return SkillStep(
        id: map['id']?.toString() ?? 'step',
        action: SkillFlowAction.values.firstWhere(
          (a) => a.name == map['action']?.toString(),
          orElse: () => SkillFlowAction.uiWait,
        ),
        label: map['label']?.toString(),
        durationMs: map['duration_ms'] is int ? map['duration_ms'] as int : null,
        tapText: map['tap_text']?.toString(),
        matchText: map['match_text']?.toString(),
        value: map['value']?.toString(),
        fieldHint: map['field_hint']?.toString(),
        expectedPackage: map['expected_package']?.toString(),
        expectVisible: map['expect_visible']?.toString(),
        expectInputEmpty: map['expect_input_empty'] == true,
      );
    }).toList();
  }

  /// Launch the app required by the contract (package manifest → installed
  /// match). No package requirement → cannot launch anything.
  Future<bool> _launchTarget(SkillContract contract) async {
    final packages = contract.requirements.package;
    if (packages == null) return false;
    try {
      final installed = await _launcher.getInstalledApps();
      for (final app in installed) {
        if (packages.matches(app.packageName)) {
          final result = await _launcher.openPackage(app.packageName);
          return result.startsWith('Launched') || result.startsWith('Opened');
        }
      }
    } catch (e) {
      developer.log('Launch lookup failed: $e', name: 'BeatriceOS');
      return false;
    }
    return false;
  }

  /// Fallback when the native text clicker missed: tap the first node whose
  /// text/description contains the match, by its bounds center.
  Future<bool> _tapNodeContaining(String match) async {
    final nodes = await _screenService.dumpScreen();
    for (final node in nodes) {
      final text = node['text'] ?? node['contentDescription'] ?? '';
      if (text.toString().toLowerCase().contains(match.toLowerCase())) {
        final bounds = node['bounds'];
        if (bounds is Map) {
          final left = (bounds['left'] as num?)?.toDouble() ?? 0;
          final right = (bounds['right'] as num?)?.toDouble() ?? 0;
          final top = (bounds['top'] as num?)?.toDouble() ?? 0;
          final bottom = (bounds['bottom'] as num?)?.toDouble() ?? 0;
          if (right > left && bottom > top) {
            return _screenService.clickAt(
              (left + right) / 2,
              (top + bottom) / 2,
            );
          }
        }
      }
    }
    return false;
  }

  /// The contract's terminal check: expected package must be foreground and
  /// any declared post-condition (e.g. the message input field cleared) must
  /// hold.
  Future<bool> _inspectScreen(SkillStep step) async {
    var passed = true;
    final notes = <String>[];

    if (step.expectedPackage != null) {
      final pkg = await _screenService.getCurrentPackage();
      if (pkg != step.expectedPackage) {
        passed = false;
        notes.add('package=$pkg (expected ${step.expectedPackage})');
      }
    }

    if (step.expectInputEmpty == true) {
      final nodes = await _screenService.dumpScreen();
      final empty = nodes.any((node) =>
          node['isEditable'] == true &&
          (node['text'] ?? '') is String &&
          (node['text'] as String).trim().isEmpty);
      if (!empty) {
        passed = false;
        notes.add('no empty input after send');
      }
    }

    developer.log(
      'Skill inspect: passed=$passed ${notes.join(', ')}',
      name: 'BeatriceOS',
    );
    return passed;
  }

  String _substitute(String value, Map<String, dynamic> inputs) {
    return value.replaceAllMapped(
      RegExp(r'\$\{\s*inputs\.([\w]+)\s*\}'),
      (m) => inputs[m.group(1)]?.toString() ?? '',
    );
  }

  /// Maps a failed contract step to the registered failure code, then a
  /// sensible terminal failure code for steps without one.
  String _failureCodeFor(String stepId, SkillContract contract) {
    if (contract.failureCodes.containsKey(stepId)) {
      return contract.failureCodes[stepId]!;
    }
    switch (stepId) {
      case 'open_whatsapp':
      case 'app_open':
      case 'verify_screen':
        return contract.failureCodes['app_not_opened'] ?? 'APP_LAUNCH_FAILED';
      case 'select_recipient':
        return contract.failureCodes['recipient_not_found'] ??
            'RECIPIENT_NOT_FOUND';
      case 'tap_send':
      case 'verify':
        return contract.failureCodes['send_failed'] ?? 'SEND_FAILED';
      default:
        return 'FLOW_FAILED:$stepId';
    }
  }
}