/// Task-flow skill contracts for the private-agent execution plane.
///
/// A contract is the single source of truth for how a skill runs on the
/// device. Neither the orchestrator nor the agent invents an execution path:
/// the runner executes the exact flow, verifies the outcome, and reports
/// terminal evidence.
library;

enum SkillFlowAction {
  /// Launch an app by package name (via known-package table or name match).
  appOpen,
  /// Pause between steps so the UI settles.
  uiWait,
  /// Tap the first node whose text equals [SkillStep.tapText].
  uiTapText,
  /// Type [SkillStep.value] into the focused or hinted field.
  uiType,
  /// Tap the first node whose text contains [SkillStep.matchText].
  uiTapFirst,
  /// Inspect the screen for package / visible text / input state.
  screenInspect,
}

class SkillStep {
  final String id;
  final SkillFlowAction action;
  final String? label;
  final int? durationMs;
  final String? tapText;
  final String? matchText;
  final String? value;
  final String? fieldHint;
  final String? expectedPackage;
  final String? expectVisible;
  final bool? expectInputEmpty;

  const SkillStep({
    required this.id,
    required this.action,
    this.label,
    this.durationMs,
    this.tapText,
    this.matchText,
    this.value,
    this.fieldHint,
    this.expectedPackage,
    this.expectVisible,
    this.expectInputEmpty,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action.name,
        'label': label,
        'durationMs': durationMs,
        'tapText': tapText,
        'matchText': matchText,
        'value': value,
        'fieldHint': fieldHint,
        'expectedPackage': expectedPackage,
        'expectVisible': expectVisible,
        'expectInputEmpty': expectInputEmpty,
      };
}

class SkillPackage {
  /// Package names that satisfy the requirement (any match).
  final List<String> packages;

  const SkillPackage.any(this.packages);

  factory SkillPackage.singleton(String package) => SkillPackage.any([package]);

  bool matches(String package) => packages.contains(package);

  Map<String, dynamic> toJson() => {'any': packages.toList()};
}

class SkillRequirements {
  /// Agent binding state required before the flow starts.
  final String agentState;
  /// Accessibility service must be enabled.
  final bool accessibility;
  /// Optional package requirement — the app must be installed.
  final SkillPackage? package;

  const SkillRequirements({
    this.agentState = 'ready',
    this.accessibility = true,
    this.package,
  });

  Map<String, dynamic> toJson() => {
        'agent_state': agentState,
        'accessibility': accessibility,
        if (package != null) 'package': package!.toJson(),
      };
}

class SkillInputSpec {
  final String name;
  final String type;
  final bool required;

  const SkillInputSpec({required this.name, required this.type, this.required = true});

  Map<String, dynamic> toJson() =>
      {'name': name, 'type': type, 'required': required};
}

/// A single registered task-flow contract.
class SkillContract {
  final String id;
  final String version;
  final String description;
  final List<SkillInputSpec> inputs;
  final SkillRequirements requirements;
  final List<SkillStep> flow;

  /// Step ids that must all pass for the run to be reported done.
  final List<String> successSteps;

  /// Failure codes keyed by name → terminal code, e.g. 'package_missing' →
  /// 'WHATSAPP_NOT_INSTALLED'.
  final Map<String, String> failureCodes;

  const SkillContract({
    required this.id,
    required this.version,
    required this.description,
    this.inputs = const [],
    required this.requirements,
    required this.flow,
    required this.successSteps,
    required this.failureCodes,
  });

  String get qualifiedId => '$id:$version';

  String get category {
    switch (id) {
      case 'whatsapp.open':
      case 'whatsapp.send_message':
        return 'Communication';
      default:
        return 'Other';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'description': description,
        'inputs': inputs.map((i) => i.toJson()).toList(),
        'requirements': requirements.toJson(),
        'flow': flow.map((s) => s.toJson()).toList(),
        'success': successSteps.map((s) => '$s == passed').toList(),
        'failure': failureCodes,
      };
}

/// A single entry in the device's registered skill catalog. Every skill the
/// agent can name or that Beatrice Voice may surface is listed here, with
/// `soon: true` marking registered-but-not-yet-implementable skills so the
/// orchestrator never claims them as available.
class SkillCatalogEntry {
  final String id;
  final String name;
  final String category;
  final bool soon;

  const SkillCatalogEntry({
    required this.id,
    required this.name,
    required this.category,
    this.soon = false,
  });

  String get qualifiedId => '$id:v1';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'version': 'v1',
        'available': !soon,
      };
}

/// Registered skill manifest. Manifest version is part of the agent profile
/// written during the binding handshake.
class SkillManifest {
  static const String version = '1';

  /// The complete skill catalog, grouped by category. `soon` entries are
  /// declared so the surface can render them but execution refuses them.
  static const List<SkillCatalogEntry> catalog = [
    // ─── Agent ────────────────────────────────────────────────────────────
    SkillCatalogEntry(id: 'agent.identity.get', name: 'Get Agent Identity', category: 'Agent'),
    SkillCatalogEntry(id: 'agent.capabilities.get', name: 'Get Agent Capabilities', category: 'Agent'),
    SkillCatalogEntry(id: 'agent.status.get', name: 'Get Agent Status', category: 'Agent'),
    SkillCatalogEntry(id: 'skill.status.get', name: 'Get Skill Status', category: 'Agent'),
    SkillCatalogEntry(id: 'skill.cancel', name: 'Cancel Skill', category: 'Agent'),
    // ─── System ───────────────────────────────────────────────────────────
    SkillCatalogEntry(id: 'system.volume.set', name: 'Set Volume', category: 'System'),
    SkillCatalogEntry(id: 'system.brightness.set', name: 'Set Brightness', category: 'System'),
    SkillCatalogEntry(id: 'system.wifi.toggle', name: 'Toggle Wi-Fi', category: 'System', soon: true),
    SkillCatalogEntry(id: 'system.bluetooth.toggle', name: 'Toggle Bluetooth', category: 'System', soon: true),
    SkillCatalogEntry(id: 'system.flashlight.toggle', name: 'Toggle Flashlight', category: 'System', soon: true),
    SkillCatalogEntry(id: 'system.power.restart', name: 'Restart Phone', category: 'System', soon: true),
    SkillCatalogEntry(id: 'system.power.shutdown', name: 'Shut Down Phone', category: 'System', soon: true),
    // ─── UI Navigation ────────────────────────────────────────────────────
    SkillCatalogEntry(id: 'screen.read', name: 'Read Screen', category: 'UI Navigation'),
    SkillCatalogEntry(id: 'screen.screenshot', name: 'Take Screenshot', category: 'UI Navigation'),
    SkillCatalogEntry(id: 'ui.home', name: 'Go Home', category: 'UI Navigation'),
    SkillCatalogEntry(id: 'ui.back', name: 'Go Back', category: 'UI Navigation'),
    SkillCatalogEntry(id: 'ui.click', name: 'Tap Element', category: 'UI Navigation'),
    SkillCatalogEntry(id: 'ui.type', name: 'Type Text', category: 'UI Navigation'),
    SkillCatalogEntry(id: 'ui.scroll', name: 'Scroll', category: 'UI Navigation'),
    SkillCatalogEntry(id: 'ui.swipe', name: 'Swipe', category: 'UI Navigation'),
    // ─── Apps ─────────────────────────────────────────────────────────────
    SkillCatalogEntry(id: 'app.open', name: 'Open App', category: 'Apps'),
    SkillCatalogEntry(id: 'app.close', name: 'Close App', category: 'Apps', soon: true),
    SkillCatalogEntry(id: 'app.list', name: 'List Installed Apps', category: 'Apps', soon: true),
    SkillCatalogEntry(id: 'app.installed.check', name: 'Check App Installed', category: 'Apps'),
    // ─── Communication ────────────────────────────────────────────────────
    SkillCatalogEntry(id: 'phone.call', name: 'Make Phone Call', category: 'Communication', soon: true),
    SkillCatalogEntry(id: 'sms.send', name: 'Send SMS', category: 'Communication', soon: true),
    SkillCatalogEntry(id: 'email.compose', name: 'Compose Email', category: 'Communication', soon: true),
    SkillCatalogEntry(id: 'whatsapp.open', name: 'Open WhatsApp', category: 'Communication'),
    SkillCatalogEntry(id: 'whatsapp.send_message', name: 'Send WhatsApp Message', category: 'Communication'),
    SkillCatalogEntry(id: 'contact.search', name: 'Search Contact', category: 'Communication', soon: true),
    // ─── Media ────────────────────────────────────────────────────────────
    SkillCatalogEntry(id: 'media.play', name: 'Play Media', category: 'Media', soon: true),
    SkillCatalogEntry(id: 'media.pause', name: 'Pause Media', category: 'Media', soon: true),
    SkillCatalogEntry(id: 'media.next', name: 'Next Track', category: 'Media', soon: true),
    SkillCatalogEntry(id: 'media.previous', name: 'Previous Track', category: 'Media', soon: true),
    SkillCatalogEntry(id: 'camera.capture', name: 'Take Photo', category: 'Media', soon: true),
    SkillCatalogEntry(id: 'gallery.open', name: 'Open Gallery', category: 'Media', soon: true),
    // ─── Productivity ─────────────────────────────────────────────────────
    SkillCatalogEntry(id: 'calendar.event.create', name: 'Create Calendar Event', category: 'Productivity', soon: true),
    SkillCatalogEntry(id: 'alarm.set', name: 'Set Alarm', category: 'Productivity', soon: true),
    SkillCatalogEntry(id: 'timer.set', name: 'Set Timer', category: 'Productivity', soon: true),
    SkillCatalogEntry(id: 'calculator.compute', name: 'Compute', category: 'Productivity'),
    SkillCatalogEntry(id: 'clipboard.copy', name: 'Copy to Clipboard', category: 'Productivity', soon: true),
    SkillCatalogEntry(id: 'clipboard.paste', name: 'Paste from Clipboard', category: 'Productivity', soon: true),
    SkillCatalogEntry(id: 'notes.create', name: 'Create Note', category: 'Productivity', soon: true),
    // ─── Web ──────────────────────────────────────────────────────────────
    SkillCatalogEntry(id: 'web.search', name: 'Web Search', category: 'Web', soon: true),
    SkillCatalogEntry(id: 'maps.open', name: 'Open Maps', category: 'Web', soon: true),
    SkillCatalogEntry(id: 'url.open', name: 'Open URL', category: 'Web', soon: true),
    SkillCatalogEntry(id: 'share.text', name: 'Share Text', category: 'Web', soon: true),
  ];

  /// Qualified ids of skills that are executable today.
  static List<String> get readyQualifiedIds => catalog
      .where((entry) => !entry.soon)
      .map((entry) => entry.qualifiedId)
      .toList(growable: false);

  /// Resolves a catalog entry by qualified id (`screen.read:v1`) or bare id.
  static SkillCatalogEntry? findEntry(String qualifiedIdOrId) {
    final q = qualifiedIdOrId.trim();
    for (final entry in catalog) {
      if (entry.qualifiedId == q || entry.id == q) return entry;
    }
    return null;
  }

  static Map<String, dynamic> toCatalogJson() => {
        'version': version,
        'skills': catalog.map((entry) => entry.toJson()).toList(),
      };

  static const List<SkillContract> contracts = [
    // ─── whatsapp.open:v1 ────────────────────────────────────────────────
    SkillContract(
      id: 'whatsapp.open',
      version: 'v1',
      description: 'Open WhatsApp.',
      requirements: SkillRequirements(
        package: SkillPackage.any(['com.whatsapp', 'com.whatsapp.w4b']),
      ),
      flow: [
        SkillStep(id: 'app_open', action: SkillFlowAction.appOpen, label: 'launch whatsapp'),
        SkillStep(id: 'wait_ui', action: SkillFlowAction.uiWait, durationMs: 800),
        SkillStep(
          id: 'verify_screen',
          action: SkillFlowAction.screenInspect,
          expectedPackage: 'com.whatsapp',
          label: 'verify current app',
        ),
      ],
      successSteps: ['verify_screen'],
      failureCodes: {
        'package_missing': 'WHATSAPP_NOT_INSTALLED',
        'app_not_opened': 'WHATSAPP_LAUNCH_FAILED',
      },
    ),

    // ─── whatsapp.send_message:v1 ────────────────────────────────────────
    SkillContract(
      id: 'whatsapp.send_message',
      version: 'v1',
      description: 'Send a WhatsApp message to a recipient.',
      inputs: [
        SkillInputSpec(name: 'recipient', type: 'string'),
        SkillInputSpec(name: 'message', type: 'string'),
      ],
      requirements: SkillRequirements(
        package: SkillPackage.any(['com.whatsapp', 'com.whatsapp.w4b']),
      ),
      flow: [
        SkillStep(id: 'open_whatsapp', action: SkillFlowAction.appOpen, label: 'launch whatsapp'),
        SkillStep(id: 'wait_ui', action: SkillFlowAction.uiWait, durationMs: 800),
        SkillStep(
          id: 'tap_search',
          action: SkillFlowAction.uiTapText,
          tapText: 'Search',
          label: 'open search',
        ),
        SkillStep(
          id: 'type_recipient',
          action: SkillFlowAction.uiType,
          value: r'${inputs.recipient}',
          fieldHint: 'search',
          label: 'type recipient',
        ),
        SkillStep(id: 'wait_results', action: SkillFlowAction.uiWait, durationMs: 500),
        SkillStep(
          id: 'select_recipient',
          action: SkillFlowAction.uiTapFirst,
          matchText: r'${inputs.recipient}',
          label: 'select recipient',
        ),
        SkillStep(
          id: 'type_message',
          action: SkillFlowAction.uiType,
          value: r'${inputs.message}',
          fieldHint: 'message',
          label: 'type message',
        ),
        SkillStep(
          id: 'tap_send',
          action: SkillFlowAction.uiTapText,
          tapText: 'Send',
          label: 'send button',
        ),
        SkillStep(
          id: 'verify',
          action: SkillFlowAction.screenInspect,
          expectInputEmpty: true,
          label: 'verify message sent',
        ),
      ],
      successSteps: ['verify'],
      failureCodes: {
        'package_missing': 'WHATSAPP_NOT_INSTALLED',
        'app_not_opened': 'WHATSAPP_LAUNCH_FAILED',
        'recipient_not_found': 'WHATSAPP_RECIPIENT_NOT_FOUND',
        'send_failed': 'WHATSAPP_SEND_FAILED',
      },
    ),
  ];

  /// Resolves a contract by qualified id (`whatsapp.send_message:v1`) or bare
  /// id (`whatsapp.send_message`).
  static SkillContract? find(String qualifiedIdOrId) {
    final q = qualifiedIdOrId.trim();
    for (final contract in contracts) {
      if (contract.qualifiedId == q || contract.id == q) return contract;
    }
    return null;
  }

  static List<String> get qualifiedIds =>
      contracts.map((c) => c.qualifiedId).toList(growable: false);

  static Map<String, dynamic> toJson() => {
        'version': version,
        'skills': contracts.map((c) => c.toJson()).toList(),
      };
}