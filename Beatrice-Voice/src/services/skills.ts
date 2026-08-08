import {
  Smartphone,
  Layers,
  Eye,
  Aperture,
  Volume2,
  Sun,
  Home,
  ArrowLeft,
  Activity,
  CircleOff,
  AppWindow,
  MousePointerClick,
  Keyboard,
  ScrollText,
  RotateCcw,
  Phone,
  MessageSquare,
  Mail,
  Music,
  Video,
  Camera,
  ImageIcon,
  MapPin,
  Calendar,
  Clock,
  AlarmClock,
  Calculator,
  Search,
  Wand2,
  Globe,
  Wifi,
  Bluetooth,
  Flashlight,
  Share2,
  Copy,
  Clipboard,
  Trash2,
  Power,
  RotateCw,
  type LucideIcon,
} from 'lucide-react';

/**
 * Skill Registry — Task Flow Contracts
 *
 * Each entry is a contract between Beatrice Voice (conversational orchestrator)
 * and the private-agent (device-execution plane). In Full Access mode the agent
 * does not ask per-action permission; it executes the predefined workflow and
 * verifies the result. Confirmation metadata here is used only for logging/audit
 * and for future non-Full-Access modes.
 */

export type SkillCategory =
  | 'agent'
  | 'system'
  | 'ui'
  | 'app'
  | 'communication'
  | 'media'
  | 'productivity'
  | 'web';

export interface SkillParameter {
  name: string;
  type: 'string' | 'number' | 'boolean' | 'enum';
  description: string;
  required: boolean;
  enum?: string[];
}

export interface SkillStep {
  id: string;
  action: string;
  target?: Record<string, unknown>;
  value?: string;
  duration_ms?: number;
  expect?: Record<string, unknown>;
}

export interface SkillContract {
  id: string;
  version: number;
  confirmation: 'none' | 'voice' | 'user';
  requirements: {
    agentState?: 'ready';
    accessibility?: boolean;
    packages?: string[];
  };
  inputs?: SkillParameter[];
  flow: SkillStep[];
  success: { when: string[] };
  failure?: Record<string, string>;
}

export interface SkillDefinition {
  id: string;
  name: string;
  description: string;
  category: SkillCategory;
  icon: LucideIcon;
  parameters: SkillParameter[];
  supported: boolean;
  requiresConfirmation?: boolean;
  dangerous?: boolean;
  version?: string;
  contract?: SkillContract;
}

export const skillCategories: Record<SkillCategory, { label: string; color: string }> = {
  agent: { label: 'Agent', color: '#60A5FA' },
  system: { label: 'System', color: '#34D399' },
  ui: { label: 'UI Navigation', color: '#F472B6' },
  app: { label: 'Apps', color: '#A78BFA' },
  communication: { label: 'Communication', color: '#FBBF24' },
  media: { label: 'Media', color: '#F87171' },
  productivity: { label: 'Productivity', color: '#22D3EE' },
  web: { label: 'Web', color: '#A3E635' },
};

const whatsappPackages = ['com.whatsapp', 'com.whatsapp.w4b'];

export const whatsappOpenContract: SkillContract = {
  id: 'whatsapp.open',
  version: 1,
  confirmation: 'none',
  requirements: {
    agentState: 'ready',
    accessibility: true,
    packages: whatsappPackages,
  },
  flow: [
    { id: 'launch', action: 'app.open', target: { packages: whatsappPackages } },
    { id: 'wait_for_ui', action: 'ui.wait', duration_ms: 800 },
    { id: 'verify_screen', action: 'screen.inspect', expect: { app: 'whatsapp' } },
  ],
  success: { when: ['verify_screen == passed'] },
  failure: {
    package_missing: 'WHATSAPP_NOT_INSTALLED',
    app_not_opened: 'WHATSAPP_LAUNCH_FAILED',
  },
};

export const whatsappSendMessageContract: SkillContract = {
  id: 'whatsapp.send_message',
  version: 1,
  confirmation: 'none',
  requirements: {
    agentState: 'ready',
    accessibility: true,
    packages: whatsappPackages,
  },
  inputs: [
    { name: 'recipient', type: 'string', description: 'Contact name to send to.', required: true },
    { name: 'message', type: 'string', description: 'Message text.', required: true },
  ],
  flow: [
    { id: 'open_whatsapp', action: 'skill.call', target: { skill: 'whatsapp.open:v1' } },
    { id: 'tap_search', action: 'ui.tap', target: { semantic: 'whatsapp.search' } },
    { id: 'type_recipient', action: 'ui.type', target: { semantic: 'whatsapp.search_field' }, value: '${inputs.recipient}' },
    { id: 'wait_results', action: 'ui.wait', duration_ms: 500 },
    { id: 'select_recipient', action: 'ui.tap', target: { semantic: 'whatsapp.contact_result', match: '${inputs.recipient}' } },
    { id: 'type_message', action: 'ui.type', target: { semantic: 'whatsapp.message_field' }, value: '${inputs.message}' },
    { id: 'tap_send', action: 'ui.tap', target: { semantic: 'whatsapp.send' } },
    { id: 'verify', action: 'screen.inspect', expect: { message_visible: '${inputs.message}' } },
  ],
  success: { when: ['verify == passed'] },
  failure: {
    recipient_not_found: 'RECIPIENT_NOT_FOUND',
    message_not_sent: 'MESSAGE_SEND_FAILED',
  },
};

export const skills: SkillDefinition[] = [
  // ─── Agent / Meta ─────────────────────────────────────────────────────
  {
    id: 'agent.identity.get',
    name: 'Get Agent Identity',
    description: 'Return the canonical agent id, owner, protocol version, and supported skill manifest.',
    category: 'agent',
    icon: Smartphone,
    parameters: [],
    supported: true,
  },
  {
    id: 'agent.capabilities.get',
    name: 'Get Agent Capabilities',
    description: 'Return the Android device profile, runtime capabilities, and supported adapters.',
    category: 'agent',
    icon: Layers,
    parameters: [],
    supported: true,
  },
  {
    id: 'agent.status.get',
    name: 'Get Agent Status',
    description: 'Return authoritative agent state: ready, bound, capabilities, installed apps, and available skills.',
    category: 'agent',
    icon: Activity,
    parameters: [],
    supported: true,
  },
  {
    id: 'skill.status.get',
    name: 'Get Skill Status',
    description: 'Return the status of a running or recent skill invocation, including verification evidence.',
    category: 'agent',
    icon: Activity,
    parameters: [
      { name: 'invocationId', type: 'string', description: 'The invocation id to inspect.', required: true },
    ],
    supported: true,
  },
  {
    id: 'skill.cancel',
    name: 'Cancel Skill',
    description: 'Request cancellation of the active skill invocation.',
    category: 'agent',
    icon: CircleOff,
    parameters: [
      { name: 'invocationId', type: 'string', description: 'The invocation id to cancel.', required: true },
    ],
    supported: true,
    requiresConfirmation: false,
  },

  // ─── System / Device Control ────────────────────────────────────────────
  {
    id: 'system.volume.set',
    name: 'Set Volume',
    description: 'Set the media volume to a level between 0 and 100.',
    category: 'system',
    icon: Volume2,
    parameters: [
      { name: 'level', type: 'number', description: 'Volume level from 0 to 100.', required: true },
      { name: 'stream', type: 'enum', description: 'Audio stream to adjust.', required: false, enum: ['media', 'alarm', 'notification', 'ring', 'call'] },
    ],
    supported: true,
  },
  {
    id: 'system.brightness.set',
    name: 'Set Brightness',
    description: 'Set the screen brightness to a level between 0 and 100.',
    category: 'system',
    icon: Sun,
    parameters: [
      { name: 'level', type: 'number', description: 'Brightness level from 0 to 100.', required: true },
    ],
    supported: true,
  },
  {
    id: 'system.wifi.toggle',
    name: 'Toggle Wi-Fi',
    description: 'Turn Wi-Fi on or off.',
    category: 'system',
    icon: Wifi,
    parameters: [
      { name: 'enabled', type: 'boolean', description: 'Target Wi-Fi state.', required: true },
    ],
    supported: false,
  },
  {
    id: 'system.bluetooth.toggle',
    name: 'Toggle Bluetooth',
    description: 'Turn Bluetooth on or off.',
    category: 'system',
    icon: Bluetooth,
    parameters: [
      { name: 'enabled', type: 'boolean', description: 'Target Bluetooth state.', required: true },
    ],
    supported: false,
  },
  {
    id: 'system.flashlight.toggle',
    name: 'Toggle Flashlight',
    description: 'Turn the camera flashlight on or off.',
    category: 'system',
    icon: Flashlight,
    parameters: [
      { name: 'enabled', type: 'boolean', description: 'Target flashlight state.', required: true },
    ],
    supported: false,
  },
  {
    id: 'system.power.restart',
    name: 'Restart Phone',
    description: 'Restart the Android device.',
    category: 'system',
    icon: RotateCw,
    parameters: [],
    supported: false,
    requiresConfirmation: false,
    dangerous: true,
  },
  {
    id: 'system.power.shutdown',
    name: 'Shut Down Phone',
    description: 'Power off the Android device.',
    category: 'system',
    icon: Power,
    parameters: [],
    supported: false,
    requiresConfirmation: false,
    dangerous: true,
  },

  // ─── UI Navigation ────────────────────────────────────────────────────
  {
    id: 'screen.read',
    name: 'Read Screen',
    description: 'Read the current accessibility tree and return a structured description of visible UI elements.',
    category: 'ui',
    icon: Eye,
    parameters: [
      { name: 'compressed', type: 'boolean', description: 'Return a token-compressed description.', required: false },
      { name: 'includeVision', type: 'boolean', description: 'Augment with on-device vision if the tree is sparse.', required: false },
    ],
    supported: true,
  },
  {
    id: 'screen.screenshot',
    name: 'Take Screenshot',
    description: 'Capture the current screen and return a base64 PNG for verification.',
    category: 'ui',
    icon: Aperture,
    parameters: [],
    supported: true,
  },
  {
    id: 'ui.home',
    name: 'Go Home',
    description: 'Press the Android Home button and return to the launcher.',
    category: 'ui',
    icon: Home,
    parameters: [],
    supported: true,
  },
  {
    id: 'ui.back',
    name: 'Go Back',
    description: 'Press the Android Back button.',
    category: 'ui',
    icon: ArrowLeft,
    parameters: [],
    supported: true,
  },
  {
    id: 'ui.click',
    name: 'Tap Element',
    description: 'Tap a visible UI element by text or coordinates.',
    category: 'ui',
    icon: MousePointerClick,
    parameters: [
      { name: 'text', type: 'string', description: 'Text of the element to tap.', required: false },
      { name: 'x', type: 'number', description: 'X coordinate.', required: false },
      { name: 'y', type: 'number', description: 'Y coordinate.', required: false },
    ],
    supported: true,
    requiresConfirmation: false,
  },
  {
    id: 'ui.type',
    name: 'Type Text',
    description: 'Type text into the focused or hinted input field.',
    category: 'ui',
    icon: Keyboard,
    parameters: [
      { name: 'text', type: 'string', description: 'Text to type.', required: true },
      { name: 'fieldHint', type: 'string', description: 'Hint text of the target field.', required: false },
    ],
    supported: true,
  },
  {
    id: 'ui.scroll',
    name: 'Scroll',
    description: 'Scroll the screen up, down, left, or right.',
    category: 'ui',
    icon: ScrollText,
    parameters: [
      { name: 'direction', type: 'enum', description: 'Scroll direction.', required: true, enum: ['up', 'down', 'left', 'right'] },
    ],
    supported: true,
  },
  {
    id: 'ui.swipe',
    name: 'Swipe',
    description: 'Swipe from one coordinate to another.',
    category: 'ui',
    icon: RotateCcw,
    parameters: [
      { name: 'startX', type: 'number', description: 'Start X coordinate.', required: true },
      { name: 'startY', type: 'number', description: 'Start Y coordinate.', required: true },
      { name: 'endX', type: 'number', description: 'End X coordinate.', required: true },
      { name: 'endY', type: 'number', description: 'End Y coordinate.', required: true },
    ],
    supported: true,
  },

  // ─── Apps ───────────────────────────────────────────────────────────────
  {
    id: 'app.open',
    name: 'Open App',
    description: 'Launch an installed app by name or package name.',
    category: 'app',
    icon: AppWindow,
    parameters: [
      { name: 'appName', type: 'string', description: 'Human-readable app name.', required: true },
      { name: 'packageName', type: 'string', description: 'Android package name, if known.', required: false },
    ],
    supported: true,
  },
  {
    id: 'app.close',
    name: 'Close App',
    description: 'Force-stop or close a recently opened app.',
    category: 'app',
    icon: Trash2,
    parameters: [
      { name: 'appName', type: 'string', description: 'Human-readable app name.', required: true },
      { name: 'packageName', type: 'string', description: 'Android package name, if known.', required: false },
    ],
    supported: false,
  },
  {
    id: 'app.list',
    name: 'List Installed Apps',
    description: 'Return a list of installed apps matching an optional query.',
    category: 'app',
    icon: Layers,
    parameters: [
      { name: 'query', type: 'string', description: 'Optional filter by app name.', required: false },
    ],
    supported: false,
  },
  {
    id: 'app.installed.check',
    name: 'Check App Installed',
    description: 'Check whether a specific app or package is installed on the device.',
    category: 'app',
    icon: Layers,
    parameters: [
      { name: 'packageName', type: 'string', description: 'Android package name.', required: true },
    ],
    supported: true,
  },

  // ─── Communication ────────────────────────────────────────────────────
  {
    id: 'phone.call',
    name: 'Make Phone Call',
    description: 'Call a contact by name or phone number.',
    category: 'communication',
    icon: Phone,
    parameters: [
      { name: 'contactName', type: 'string', description: 'Contact name to search.', required: false },
      { name: 'phoneNumber', type: 'string', description: 'Phone number to dial.', required: false },
    ],
    supported: false,
    requiresConfirmation: false,
  },
  {
    id: 'sms.send',
    name: 'Send SMS',
    description: 'Send a text message to a contact or number.',
    category: 'communication',
    icon: MessageSquare,
    parameters: [
      { name: 'contactName', type: 'string', description: 'Contact name to search.', required: false },
      { name: 'phoneNumber', type: 'string', description: 'Phone number.', required: false },
      { name: 'message', type: 'string', description: 'Message text.', required: true },
    ],
    supported: false,
    requiresConfirmation: false,
  },
  {
    id: 'email.compose',
    name: 'Compose Email',
    description: 'Open the default email app with a pre-filled recipient, subject, and body.',
    category: 'communication',
    icon: Mail,
    parameters: [
      { name: 'to', type: 'string', description: 'Recipient email address.', required: true },
      { name: 'subject', type: 'string', description: 'Email subject.', required: false },
      { name: 'body', type: 'string', description: 'Email body.', required: false },
    ],
    supported: false,
    requiresConfirmation: false,
  },
  {
    id: 'whatsapp.open',
    name: 'Open WhatsApp',
    description: 'Launch WhatsApp and verify it is on screen.',
    category: 'communication',
    icon: MessageSquare,
    parameters: [],
    supported: true,
    version: '1',
    contract: whatsappOpenContract,
  },
  {
    id: 'whatsapp.send_message',
    name: 'Send WhatsApp Message',
    description: 'Open WhatsApp, find a recipient, type a message, send it, and verify the message is visible.',
    category: 'communication',
    icon: MessageSquare,
    parameters: [
      { name: 'recipient', type: 'string', description: 'Contact name to send to.', required: true },
      { name: 'message', type: 'string', description: 'Message text.', required: true },
    ],
    supported: true,
    version: '1',
    contract: whatsappSendMessageContract,
  },
  {
    id: 'contact.search',
    name: 'Search Contact',
    description: 'Search the device contacts and return matching entries.',
    category: 'communication',
    icon: Search,
    parameters: [
      { name: 'query', type: 'string', description: 'Name or phone number to search.', required: true },
    ],
    supported: false,
  },

  // ─── Media ─────────────────────────────────────────────────────────────
  {
    id: 'media.play',
    name: 'Play Media',
    description: 'Play music, video, or a specific track in a media app.',
    category: 'media',
    icon: Music,
    parameters: [
      { name: 'appName', type: 'string', description: 'Media app to use.', required: false },
      { name: 'query', type: 'string', description: 'Song, artist, playlist, or video to play.', required: true },
    ],
    supported: false,
  },
  {
    id: 'media.pause',
    name: 'Pause Media',
    description: 'Pause currently playing media.',
    category: 'media',
    icon: Video,
    parameters: [],
    supported: false,
  },
  {
    id: 'media.next',
    name: 'Next Track',
    description: 'Skip to the next track in the active media app.',
    category: 'media',
    icon: Music,
    parameters: [],
    supported: false,
  },
  {
    id: 'media.previous',
    name: 'Previous Track',
    description: 'Go back to the previous track in the active media app.',
    category: 'media',
    icon: Music,
    parameters: [],
    supported: false,
  },
  {
    id: 'camera.capture',
    name: 'Take Photo',
    description: 'Open the camera app and take a photo.',
    category: 'media',
    icon: Camera,
    parameters: [
      { name: 'camera', type: 'enum', description: 'Which camera to use.', required: false, enum: ['front', 'back'] },
    ],
    supported: false,
  },
  {
    id: 'gallery.open',
    name: 'Open Gallery',
    description: 'Open the photo gallery to a specific album or date.',
    category: 'media',
    icon: ImageIcon,
    parameters: [
      { name: 'album', type: 'string', description: 'Album name.', required: false },
    ],
    supported: false,
  },

  // ─── Productivity ──────────────────────────────────────────────────────
  {
    id: 'calendar.event.create',
    name: 'Create Calendar Event',
    description: 'Create a new calendar event with title, time, and optional reminder.',
    category: 'productivity',
    icon: Calendar,
    parameters: [
      { name: 'title', type: 'string', description: 'Event title.', required: true },
      { name: 'startTime', type: 'string', description: 'ISO 8601 start time.', required: true },
      { name: 'endTime', type: 'string', description: 'ISO 8601 end time.', required: false },
      { name: 'description', type: 'string', description: 'Event description.', required: false },
      { name: 'reminderMinutes', type: 'number', description: 'Minutes before event to remind.', required: false },
    ],
    supported: false,
    requiresConfirmation: false,
  },
  {
    id: 'alarm.set',
    name: 'Set Alarm',
    description: 'Set a one-time or recurring alarm.',
    category: 'productivity',
    icon: AlarmClock,
    parameters: [
      { name: 'hour', type: 'number', description: 'Hour (0-23).', required: true },
      { name: 'minute', type: 'number', description: 'Minute (0-59).', required: true },
      { name: 'label', type: 'string', description: 'Alarm label.', required: false },
      { name: 'repeat', type: 'boolean', description: 'Whether the alarm repeats.', required: false },
    ],
    supported: false,
    requiresConfirmation: false,
  },
  {
    id: 'timer.set',
    name: 'Set Timer',
    description: 'Set a countdown timer.',
    category: 'productivity',
    icon: Clock,
    parameters: [
      { name: 'seconds', type: 'number', description: 'Timer duration in seconds.', required: true },
      { name: 'label', type: 'string', description: 'Timer label.', required: false },
    ],
    supported: false,
  },
  {
    id: 'calculator.compute',
    name: 'Compute',
    description: 'Evaluate a math expression.',
    category: 'productivity',
    icon: Calculator,
    parameters: [
      { name: 'expression', type: 'string', description: 'Math expression to evaluate.', required: true },
    ],
    supported: true,
  },
  {
    id: 'clipboard.copy',
    name: 'Copy to Clipboard',
    description: 'Copy provided text to the device clipboard.',
    category: 'productivity',
    icon: Copy,
    parameters: [
      { name: 'text', type: 'string', description: 'Text to copy.', required: true },
    ],
    supported: false,
  },
  {
    id: 'clipboard.paste',
    name: 'Paste from Clipboard',
    description: 'Paste the current clipboard text into the focused field.',
    category: 'productivity',
    icon: Clipboard,
    parameters: [],
    supported: false,
  },
  {
    id: 'notes.create',
    name: 'Create Note',
    description: 'Create a note in the default notes app.',
    category: 'productivity',
    icon: Clipboard,
    parameters: [
      { name: 'title', type: 'string', description: 'Note title.', required: false },
      { name: 'body', type: 'string', description: 'Note body.', required: true },
    ],
    supported: false,
  },


  {
    id: 'skill.generate',
    name: 'Generate Skill',
    description: 'Create a new device skill flow contract when the user asks for an action that is not currently supported. The orchestrator describes the desired skill, and the private-agent registers it.',
    category: 'agent',
    icon: Wand2,
    parameters: [
      { name: 'skill_name', type: 'string', description: 'Short snake_case id for the new skill, e.g. settings.wifi.toggle.', required: true },
      { name: 'category', type: 'enum', description: 'Skill category.', required: true, enum: ['agent', 'system', 'ui', 'app', 'communication', 'media', 'productivity', 'web'] },
      { name: 'description', type: 'string', description: 'What the skill does in plain language.', required: true },
      { name: 'inputs', type: 'string', description: 'JSON array of {name, type, required, description} input specs.', required: false },
      { name: 'flow', type: 'string', description: 'JSON array of skill steps using actions: appOpen, uiWait, uiTapText, uiType, uiTapFirst, screenInspect.', required: true },
    ],
    supported: true,
    contract: {
      id: 'skill.generate',
      version: 1,
      confirmation: 'voice',
      requirements: { agentState: 'ready', accessibility: true },
      inputs: [
        { name: 'skill_name', type: 'string', description: 'Short snake_case id for the new skill.', required: true },
        { name: 'category', type: 'enum', description: 'Skill category.', required: true, enum: ['agent', 'system', 'ui', 'app', 'communication', 'media', 'productivity', 'web'] },
        { name: 'description', type: 'string', description: 'What the skill does.', required: true },
        { name: 'inputs', type: 'string', description: 'JSON array of input specs.', required: false },
        { name: 'flow', type: 'string', description: 'JSON array of skill steps.', required: true },
      ],
      flow: [
        { id: 'validate', action: 'screenInspect', expect: { agent_ready: true }, target: { label: 'validate skill request' } },
        { id: 'register', action: 'screenInspect', expect: { register_skill: '\${inputs.skill_name}' }, target: { label: 'register new skill contract' } },
      ],
      success: { when: ['validate == passed', 'register == passed'] },
      failure: {
        AGENT_NOT_READY: 'Agent is not ready to register skills.',
        SKILL_REGISTER_FAILED: 'Failed to register the generated skill contract.',
      },
    },
  },
  // ─── Web / Search ──────────────────────────────────────────────────────
  {
    id: 'web.search',
    name: 'Web Search',
    description: 'Open Chrome, search the web, read the results, and optionally open or scrape the top result.',
    category: 'web',
    icon: Globe,
    parameters: [
      { name: 'query', type: 'string', description: 'Search query to type in the Chrome address bar.', required: true },
      { name: 'open_top_result', type: 'boolean', description: 'Open the first search result after reading the results page.', required: false },
      { name: 'scrape_top_result', type: 'boolean', description: 'Read the content of the opened top result page.', required: false },
    ],
    supported: true,
    contract: {
      id: 'web.search',
      version: 1,
      confirmation: 'none',
      requirements: {
        agentState: 'ready',
        accessibility: true,
        packages: ['com.android.chrome', 'com.google.android.googlequicksearchbox'],
      },
      inputs: [
        { name: 'query', type: 'string', description: 'Search query.', required: true },
        { name: 'open_top_result', type: 'boolean', description: 'Open the first result after reading the results page.', required: false },
        { name: 'scrape_top_result', type: 'boolean', description: 'Read content from the opened top result.', required: false },
      ],
      flow: [
        { id: 'open_chrome', action: 'appOpen', target: { label: 'launch chrome' } },
        { id: 'wait_chrome', action: 'uiWait', duration_ms: 1200, target: { label: 'wait for chrome' } },
        { id: 'focus_address_bar', action: 'uiTapFirst', target: { match_text: 'Search or type web address', label: 'focus address bar' } },
        { id: 'wait_focus', action: 'uiWait', duration_ms: 400 },
        { id: 'type_query', action: 'uiType', value: '${inputs.query}', target: { field_hint: 'Search or type web address', label: 'type search query' } },
        { id: 'wait_typing', action: 'uiWait', duration_ms: 400 },
        { id: 'submit_search', action: 'uiTapFirst', target: { match_text: 'google.com/search', label: 'submit search' } },
        { id: 'wait_results_page', action: 'uiWait', duration_ms: 1500 },
        { id: 'read_results', action: 'screenInspect', expect: { visible: 'Search results' }, target: { label: 'read search results on screen' } },
      ],
      success: { when: ['read_results == passed'] },
      failure: {
        BROWSER_NOT_INSTALLED: 'Chrome or Google Search is not installed.',
        BROWSER_LAUNCH_FAILED: 'Chrome failed to open.',
        ADDRESS_BAR_FOCUS_FAILED: 'Could not focus the Chrome address bar.',
        SEARCH_SUBMIT_FAILED: 'The search query was not submitted.',
        NO_SEARCH_RESULTS: 'No search results were loaded on screen.',
      },
    },
  },
  {
    id: 'maps.open',
    name: 'Open Maps',
    description: 'Open Google Maps to a location, contact, or directions.',
    category: 'web',
    icon: MapPin,
    parameters: [
      { name: 'destination', type: 'string', description: 'Destination query.', required: true },
      { name: 'mode', type: 'enum', description: 'Travel mode.', required: false, enum: ['driving', 'walking', 'transit', 'bicycling'] },
    ],
    supported: false,
  },
  {
    id: 'url.open',
    name: 'Open URL',
    description: 'Open a web URL in the default browser.',
    category: 'web',
    icon: Globe,
    parameters: [
      { name: 'url', type: 'string', description: 'URL to open.', required: true },
    ],
    supported: false,
  },
  {
    id: 'share.text',
    name: 'Share Text',
    description: 'Open the native share sheet with the provided text.',
    category: 'web',
    icon: Share2,
    parameters: [
      { name: 'text', type: 'string', description: 'Text to share.', required: true },
      { name: 'subject', type: 'string', description: 'Share subject.', required: false },
    ],
    supported: false,
  },
];

export function getSkillsByCategory(): Record<SkillCategory, SkillDefinition[]> {
  return skills.reduce((acc, skill) => {
    acc[skill.category] = acc[skill.category] || [];
    acc[skill.category].push(skill);
    return acc;
  }, {} as Record<SkillCategory, SkillDefinition[]>);
}

export function getSupportedSkills(): SkillDefinition[] {
  return skills.filter((s) => s.supported);
}

export function getSkillById(id: string): SkillDefinition | undefined {
  return skills.find((s) => s.id === id);
}

export function getSkillContract(id: string): SkillContract | undefined {
  return getSkillById(id)?.contract;
}
