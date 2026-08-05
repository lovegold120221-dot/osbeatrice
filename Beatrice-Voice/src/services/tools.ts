import { FunctionDeclaration, Type } from "@google/genai";
import { get, push, ref, set, update } from "firebase/database";
import { auth, database } from "../lib/firebase";

export type TaskExecutorPermission = "ask-first" | "allow-full";

declare global {
  interface Window {
    BeatriceBridge?: { postMessage(message: string): void };
  }
}

export const calculatorTool: FunctionDeclaration = {
  name: "calculate",
  description: "Perform basic mathematical calculations.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      operation: {
        type: Type.STRING,
        enum: ["add", "subtract", "multiply", "divide"],
        description: "The mathematical operation to perform.",
      },
      a: { type: Type.NUMBER, description: "First operand." },
      b: { type: Type.NUMBER, description: "Second operand." },
    },
    required: ["operation", "a", "b"],
  },
};

export const calendarTool: FunctionDeclaration = {
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
  description: "Delegate a task to the tasker agent. Use this when the user asks you to perform an action, create something, run code, automate a workflow, or execute any task that requires multi-step execution. The tasker agent will handle the task asynchronously and report back.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      task: {
        type: Type.STRING,
        description: "The task description or prompt to send to the tasker agent. Be specific and detailed about what needs to be done.",
      },
      priority: {
        type: Type.STRING,
        enum: ["low", "normal", "high", "urgent"],
        description: "The priority level of the task.",
      },
      confirmed: {
        type: Type.BOOLEAN,
        description: "Set true only after the user has clearly confirmed the summarized device plan while Task Executor permission is Ask First.",
      },
    },
    required: ["task"],
  },
};

export const tools = [calculatorTool, calendarTool, taskerTool];

/**
 * Sends high-level device goals to the trusted Flutter WebView host. This is
 * deliberately unavailable in a normal browser: deployed Beatrice must never
 * pretend it can operate a phone when no private-agent host is connected.
 */
let embeddedDeviceId: string | null = null;
let embeddedOwnerUid: string | null = null;
let taskExecutorPermission: TaskExecutorPermission = "allow-full";

export function setEmbeddedDeviceId(deviceId: string | null) {
  embeddedDeviceId = deviceId;
}

export function setEmbeddedOwnerUid(ownerUid: string | null) {
  embeddedOwnerUid = ownerUid;
}

export function setTaskExecutorPermission(permission: TaskExecutorPermission) {
  taskExecutorPermission = permission;
}

/**
 * Registers the Flutter-generated device id against the currently signed-in
 * Beatrice account. Both records are written atomically so the web app can
 * find its paired device and task dispatch can verify ownership.
 */
export async function pairEmbeddedDevice(deviceId: string) {
  const user = auth.currentUser;
  if (!deviceId || !user) return false;

  const pairedAt = Date.now();
  await update(ref(database), {
    [`users/${user.uid}/devices/${deviceId}`]: {
      deviceId,
      pairedAt,
      lastSeenAt: pairedAt,
    },
    [`devicePairs/${deviceId}`]: {
      deviceId,
      ownerUid: user.uid,
      pairedAt,
      lastSeenAt: pairedAt,
    },
  });
  return true;
}

async function dispatchDeviceTask(args: {
  task?: string;
  priority?: string;
  confirmed?: boolean;
}) {
  if (typeof window === "undefined" || !embeddedDeviceId || !embeddedOwnerUid || !auth.currentUser) {
    return {
      status: "unavailable",
      message: "Connect Beatrice Voice to a signed-in paired mobile app before sending a device task.",
    };
  }

  if (taskExecutorPermission === "ask-first" && args.confirmed !== true) {
    return {
      status: "confirmation_required",
      message: "Summarize the planned phone actions and ask the user for a clear confirmation. Only after they confirm may you call executeTask again with confirmed set to true.",
    };
  }

  const pairing = await get(ref(database, `devicePairs/${embeddedDeviceId}`));
  if (!pairing.exists() || pairing.val()?.ownerUid !== embeddedOwnerUid) {
    return {
      status: "unavailable",
      message: "This mobile agent is not paired with the signed-in Beatrice account yet.",
    };
  }

  const taskRef = push(ref(database, `deviceTasks/${embeddedDeviceId}`));
  await set(taskRef, {
    id: taskRef.key,
    ownerUid: embeddedOwnerUid,
    goal: args.task || "",
    priority: args.priority || "normal",
    permissionMode: taskExecutorPermission,
    status: "incoming",
    createdAt: Date.now(),
  });
  window.dispatchEvent(new CustomEvent('beatrice-task-created', {
    detail: { deviceId: embeddedDeviceId, taskId: taskRef.key },
  }));
  return { status: "accepted", taskId: taskRef.key, willContinue: true };
}

export async function executeTool(name: string, args: any) {
  if (name === "calculate") {
    const { operation, a, b } = args;
    switch (operation) {
      case "add": return { result: a + b };
      case "subtract": return { result: a - b };
      case "multiply": return { result: a * b };
      case "divide": return { result: b !== 0 ? a / b : "Cannot divide by zero" };
      default: return { error: "Unknown operation" };
    }
  }
  if (name === "getCalendarEvents") {
    // Mock implementation
    return { events: [{ title: "Meeting", time: "10:00 AM" }, { title: "Lunch", time: "1:00 PM" }] };
  }
  if (name === "executeTask") {
    return dispatchDeviceTask(args);
  }
  return { error: "Unknown tool" };
}
