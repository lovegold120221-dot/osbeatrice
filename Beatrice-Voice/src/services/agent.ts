import { auth, database } from "../lib/firebase";
import { get, ref } from "firebase/database";

export interface AgentState {
  agentId: string;
  ownerUid: string;
  state: string;
  access: string;
  capabilities: Record<string, unknown>;
  apps: Record<string, { installed: boolean; packageName?: string; version?: string }>;
  skills: string[];
}

export async function fetchAgentState(agentId: string): Promise<AgentState | null> {
  const snapshot = await get(ref(database, `agentState/${agentId}`));
  if (!snapshot.exists()) return null;
  const data = snapshot.val();
  return {
    agentId: data.agentId,
    ownerUid: data.ownerUid,
    state: data.state,
    access: data.access,
    capabilities: data.capabilities || {},
    apps: data.apps || {},
    skills: data.skills || [],
  };
}

export async function requestAgentStatus(): Promise<void> {
  if (typeof window === "undefined") return;
  window.BeatriceBridge?.postMessage(JSON.stringify({ type: "agent.status.get" }));
}

export async function requestAgentCapabilities(): Promise<void> {
  if (typeof window === "undefined") return;
  window.BeatriceBridge?.postMessage(JSON.stringify({ type: "agent.capabilities.get" }));
}
