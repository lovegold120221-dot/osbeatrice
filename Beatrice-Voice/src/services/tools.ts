import { Type, Behavior, type FunctionDeclaration } from "@google/genai";
import { auth, database } from "../lib/firebase";
import { get, push, ref, set } from "firebase/database";

const calculatorTool: FunctionDeclaration = {
  name: "calculate",
  description: "Perform basic math operations.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      operation: {
        type: Type.STRING,
        enum: ["add", "subtract", "multiply", "divide"],
      },
      a: { type: Type.NUMBER },
      b: { type: Type.NUMBER },
    },
    required: ["operation", "a", "b"],
  },
};

const calendarTool: FunctionDeclaration = {
  name: "getCalendarEvents",
  description: "Get calendar events for a specific date.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      date: { type: Type.STRING, description: "The date in YYYY-MM-DD format." },
    },
    required: ["date"],
  },
};

export const taskerTool: FunctionDeclaration = {
  name: "executeTask",
  description:
    "Delegate a device task to the Beatrice OS agent. Use this when the user asks for a mobile action such as opening an app, sending a message, or changing a system setting. The agent executes asynchronously; the conversation continues immediately. Only the skill id and parameters matter.",
  behavior: Behavior.NON_BLOCKING,
  parameters: {
    type: Type.OBJECT,
    properties: {
      task: {
        type: Type.STRING,
        description:
          "The task description or prompt to send to the agent. Be specific and detailed about what needs to be done.",
      },
      priority: {
        type: Type.STRING,
        enum: ["low", "normal", "high", "urgent"],
        description: "The priority level of the task.",
      },
      confirmed: {
        type: Type.BOOLEAN,
        description:
          "Set true only after the user has clearly confirmed the summarized device plan while Task Executor permission is Ask First.",
      },
    },
    required: ["task"],
  },
};

export const tools = [calculatorTool, calendarTool, taskerTool];

export type TaskExecutorPermission = "allow-full" | "ask-first";

/**
 * Embedded Beatrice OS agent state.
 *
 * The mobile app owns the agent identity and is the authoritative owner. The
 * web session is a temporary authorized participant bound by
 * `webSessionBindings/{webSessionUid}`.
 */
let embeddedAgentId: string | null = null;
let embeddedOwnerUid: string | null = null;
let taskExecutorPermission: TaskExecutorPermission = "allow-full";

export function setEmbeddedAgentId(agentId: string | null) {
  embeddedAgentId = agentId;
}

export function setEmbeddedOwnerUid(ownerUid: string | null) {
  embeddedOwnerUid = ownerUid;
}

export function setTaskExecutorPermission(permission: TaskExecutorPermission) {
  taskExecutorPermission = permission;
}

async function fetchAgentState(): Promise<{
  agentId: string;
  ownerUid: string;
  state: string;
  access: string;
  skills: string[];
} | null> {
  if (!embeddedAgentId || !embeddedOwnerUid) return null;
  try {
    const snapshot = await get(ref(database, `agentState/${embeddedAgentId}`));
    if (!snapshot.exists()) return null;
    const state = snapshot.val();
    if (state?.ownerUid !== embeddedOwnerUid) return null;
    return {
      agentId: state.agentId,
      ownerUid: state.ownerUid,
      state: state.state,
      access: state.access,
      skills: state.skills ?? [],
    };
  } catch {
    return null;
  }
}

async function dispatchDeviceTask(args: {
  skill?: string;
  skillVersion?: number;
  task?: string;
  priority?: string;
  confirmed?: boolean;
  params?: Record<string, unknown>;
}) {
  if (
    typeof window === "undefined" ||
    !embeddedAgentId ||
    !embeddedOwnerUid ||
    !auth.currentUser
  ) {
    return {
      status: "unavailable",
      message:
        "Connect Beatrice Voice to a signed-in paired mobile app before sending a device task.",
    };
  }

  // In Full Access mode, per-action confirmation is not required. In ask-first
  // mode we would require the user to confirm before enqueuing.
  if (taskExecutorPermission === "ask-first" && args.confirmed !== true) {
    return {
      status: "confirmation_required",
      message:
        "Summarize the planned phone actions and ask the user for a clear confirmation. Only after they confirm may you call executeTask again with confirmed set to true.",
    };
  }

  const webSessionUid = auth.currentUser.uid;
  console.log("[BRIDGE]", { agentId: embeddedAgentId, ownerUid: embeddedOwnerUid, webSessionUid });

  // Verify the web session is bound to this owner and agent.
  const binding = await get(ref(database, `webSessionBindings/${webSessionUid}`));
  if (
    !binding.exists() ||
    binding.val()?.ownerUid !== embeddedOwnerUid ||
    binding.val()?.agentId !== embeddedAgentId
  ) {
    console.warn("[BRIDGE] binding=INVALID", { webSessionUid });
    return {
      status: "unavailable",
      message:
        "This web session is not bound to the paired mobile agent. Re-open Beatrice Voice from the app.",
    };
  }

  // Verify the agent profile confirms the same owner.
  const profile = await get(ref(database, `agentProfiles/${embeddedAgentId}`));
  if (!profile.exists() || profile.val()?.ownerUid !== embeddedOwnerUid) {
    return {
      status: "unavailable",
      message:
        "This mobile agent is not paired with the signed-in Beatrice account yet.",
    };
  }

  // Verify the canonical device pairing record exists and matches.
  const pairRecord = await get(ref(database, `devicePairs/${embeddedAgentId}`));
  if (!pairRecord.exists() || pairRecord.val()?.ownerUid !== embeddedOwnerUid) {
    return {
      status: "unavailable",
      message:
        "This mobile agent is not paired with the signed-in Beatrice account yet.",
    };
  }

  // Query authoritative agent state for capability/skill availability.
  const agentState = await fetchAgentState();
  if (!agentState || agentState.state !== "ready") {
    return {
      status: "unavailable",
      message:
        "The private-agent is not in ready state yet. Wait for agent.bound before executing device skills.",
    };
  }

  const skillId = args.skill ? `${args.skill}:v${args.skillVersion ?? 1}` : null;
  if (skillId && !agentState.skills.includes(skillId)) {
    return {
      status: "unsupported_skill",
      message: `Skill ${skillId} is not reported as available by the private-agent.`,
    };
  }

  const taskRef = push(ref(database, `deviceTasks/${embeddedAgentId}`));
  await set(taskRef, {
    id: taskRef.key,
    ownerUid: embeddedOwnerUid,
    goal: args.task || "",
    skill: args.skill || null,
    skillVersion: args.skillVersion || null,
    params: args.params || null,
    priority: args.priority || "normal",
    permissionMode: taskExecutorPermission,
    status: "incoming",
    createdAt: Date.now(),
  });
  console.log("[TASK] firebase.created", { agentId: embeddedAgentId, taskId: taskRef.key });

  return { status: "accepted", taskId: taskRef.key, willContinue: true };
}

export async function executeTool(name: string, args: any) {
  if (name === "calculate") {
    const { operation, a, b } = args;
    switch (operation) {
      case "add":
        return { result: a + b };
      case "subtract":
        return { result: a - b };
      case "multiply":
        return { result: a * b };
      case "divide":
        return { result: b !== 0 ? a / b : "Cannot divide by zero" };
      default:
        return { error: "Unknown operation" };
    }
  }
  if (name === "getCalendarEvents") {
    // Mock implementation
    return {
      events: [
        { title: "Meeting", time: "10:00 AM" },
        { title: "Lunch", time: "1:00 PM" },
      ],
    };
  }
  if (name === "executeTask") {
    return dispatchDeviceTask(args);
  }
  return { error: "Unknown tool" };
}
