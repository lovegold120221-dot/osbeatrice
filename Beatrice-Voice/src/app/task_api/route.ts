import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const GEMINI_OPENAI_URL =
  'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
const AGENT_ID_PATTERN = /^[A-Za-z0-9_-]{12,128}$/;
const MAX_MESSAGES = 64;
const MAX_CONTENT_LENGTH = 48_000;

const FIREBASE_LOOKUP_URL =
  'https://identitytoolkit.googleapis.com/v1/accounts:lookup';
const FIREBASE_DATABASE_URL = process.env.NEXT_PUBLIC_FIREBASE_DATABASE_URL;

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
}

export interface TaskRequest {
  model?: string;
  messages?: ChatMessage[];
  temperature?: number;
  max_tokens?: number;
  stream?: boolean;
}

function badRequest(message: string) {
  return NextResponse.json({ error: { message } }, { status: 400 });
}

function validateRequest(payload: unknown): TaskRequest | null {
  if (!payload || typeof payload !== 'object') return null;
  const request = payload as TaskRequest;
  if (
    !Array.isArray(request.messages) ||
    request.messages.length === 0 ||
    request.messages.length > MAX_MESSAGES
  ) {
    return null;
  }

  for (const message of request.messages) {
    if (
      !message ||
      !['system', 'user', 'assistant', 'tool'].includes(message.role) ||
      typeof message.content !== 'string' ||
      message.content.length > MAX_CONTENT_LENGTH
    ) {
      return null;
    }
  }

  return request;
}

interface FirebaseLookupResult {
  users?: Array<{ localId?: string; [key: string]: unknown }>;
}

async function validateFirebaseSession(
  request: NextRequest,
): Promise<{ valid: false } | { valid: true; uid: string }> {
  const firebaseApiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
  const authorization = request.headers.get('authorization');
  const idToken = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!firebaseApiKey || !idToken) return { valid: false };

  try {
    const response = await fetch(
      `${FIREBASE_LOOKUP_URL}?key=${firebaseApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken }),
        cache: 'no-store',
        signal: AbortSignal.timeout(10_000),
      },
    );
    if (!response.ok) return { valid: false };
    const result = (await response.json()) as FirebaseLookupResult;
    const uid = result.users?.[0]?.localId;
    if (!uid) return { valid: false };
    return { valid: true, uid };
  } catch {
    return { valid: false };
  }
}

async function agentProfileOwnerUid(agentId: string): Promise<string | null> {
  if (!FIREBASE_DATABASE_URL) return null;
  const firebaseApiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
  if (!firebaseApiKey) return null;

  try {
    const url = new URL(
      `${FIREBASE_DATABASE_URL}/agentProfiles/${agentId}.json`,
    );
    url.searchParams.set('auth', firebaseApiKey);
    const response = await fetch(url.toString(), {
      method: 'GET',
      cache: 'no-store',
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) return null;
    const data = (await response.json()) as { ownerUid?: string } | null;
    return data?.ownerUid ?? null;
  } catch {
    return null;
  }
}

/**
 * Server-only Gemini gateway for the Android executor.
 *
 * TASKER_API_KEY must be set in Vercel. It is intentionally never read from a
 * NEXT_PUBLIC_ variable and is never sent to the Flutter client.
 *
 * Authorization now binds the authenticated Firebase UID to the claimed
 * agentId via `agentProfiles/{agentId}/ownerUid`. A token alone is not enough.
 */
export async function POST(request: NextRequest) {
  const apiKey = process.env.TASKER_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: { message: 'Task service is not configured.' } },
      { status: 503 },
    );
  }

  const agentId = request.headers.get('x-beatrice-device-id')?.trim() ?? '';
  if (!AGENT_ID_PATTERN.test(agentId)) {
    return badRequest('A valid Beatrice agent identifier is required.');
  }

  const session = await validateFirebaseSession(request);
  if (!session.valid) {
    return NextResponse.json(
      { error: { message: 'Sign in through Beatrice OS before using the task service.' } },
      { status: 401 },
    );
  }

  const profileOwnerUid = await agentProfileOwnerUid(agentId);
  if (!profileOwnerUid || profileOwnerUid !== session.uid) {
    return NextResponse.json(
      { error: { message: 'The authenticated account does not own this Beatrice agent.' } },
      { status: 403 },
    );
  }

  let rawPayload: unknown;
  try {
    rawPayload = await request.json();
  } catch {
    return badRequest('Request body must be valid JSON.');
  }

  const payload = validateRequest(rawPayload);
  if (!payload) {
    return badRequest('Task request has an invalid chat payload.');
  }

  const upstreamPayload = {
    model: typeof payload.model === 'string' ? payload.model : 'gemini-2.5-flash',
    messages: payload.messages,
    temperature:
      typeof payload.temperature === 'number' && Number.isFinite(payload.temperature)
        ? Math.max(0, Math.min(2, payload.temperature))
        : 1,
    max_tokens:
      typeof payload.max_tokens === 'number' && Number.isFinite(payload.max_tokens)
        ? Math.max(1, Math.min(16_384, Math.floor(payload.max_tokens)))
        : 4_096,
    stream: payload.stream === true,
  };

  let upstream: Response;
  try {
    upstream = await fetch(GEMINI_OPENAI_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(upstreamPayload),
      signal: AbortSignal.timeout(90_000),
      cache: 'no-store',
    });
  } catch {
    return NextResponse.json(
      { error: { message: 'The task model could not be reached. Please retry.' } },
      { status: 502 },
    );
  }

  const contentType = upstream.headers.get('content-type') ?? 'application/json';
  const safeHeaders = new Headers({
    'Content-Type': contentType,
    'Cache-Control': 'no-store',
  });

  return new NextResponse(upstream.body, {
    status: upstream.status,
    headers: safeHeaders,
  });
}

export function OPTIONS() {
  return new NextResponse(null, { status: 204, headers: { Allow: 'POST, OPTIONS' } });
}
