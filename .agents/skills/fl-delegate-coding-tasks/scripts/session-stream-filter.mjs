#!/usr/bin/env node

import { spawn } from 'node:child_process';
import readline from 'node:readline';

const DEFAULT_MAX_SUMMARY_CHARS = 2000;
const MAX_ACTIVITY_CHARS = 240;
const MAX_STDERR_CHARS = 2000;
const ID_KEYS = new Set(['conversation_id', 'conversationId', 'session_id', 'sessionId', 'thread_id', 'threadId', 'task_id', 'taskId']);
const TEXT_KEYS = ['summary', 'result', 'output', 'final_response', 'finalResponse', 'response', 'message', 'content', 'text', 'error'];

function usage(message) {
  if (message) process.stderr.write(`${message}\n`);
  process.stderr.write('Usage: session-stream-filter.mjs [--profile <name>] [--max-summary-chars <count>] -- <command> [args...]\n');
  process.exit(2);
}

function parseArgs(argv) {
  const separator = argv.indexOf('--');
  if (separator < 0 || separator === argv.length - 1) usage('必须使用 -- 分隔过滤参数与执行器命令');
  const options = { profile: 'generic', maxSummaryChars: DEFAULT_MAX_SUMMARY_CHARS };
  for (let index = 0; index < separator; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) usage(`${key ?? '<unknown>'} 缺少值`);
    if (key === '--profile') options.profile = value;
    else if (key === '--max-summary-chars') {
      const parsed = Number(value);
      if (!Number.isInteger(parsed) || parsed < 200 || parsed > 8000) usage('--max-summary-chars 必须是 200 到 8000 的整数');
      options.maxSummaryChars = parsed;
    } else usage(`未知参数：${key}`);
  }
  return { options, command: argv[separator + 1], args: argv.slice(separator + 2) };
}

function compactText(value, maximum) {
  if (value === undefined || value === null) return null;
  const text = (typeof value === 'string' ? value : JSON.stringify(value)).replace(/\s+/g, ' ').trim();
  if (!text) return null;
  return text.length <= maximum ? text : `${text.slice(0, maximum)}…`;
}

function redactActivity(value) {
  return value
    .replace(/\bBearer\s+[^\s,;]+/gi, 'Bearer [REDACTED]')
    .replace(/\b(sk-[A-Za-z0-9_-]{8,})\b/g, '[REDACTED]')
    .replace(/\b(api[_-]?key|access[_-]?token|token|password|secret)\s*[:=]\s*[^\s,;]+/gi, '$1=[REDACTED]');
}

function safeLabel(value) {
  if (typeof value !== 'string') return null;
  const label = value.replace(/[^A-Za-z0-9_.:/-]/g, '').slice(0, 80);
  return label || null;
}

function normalizeActivity(event, profile) {
  if (event?.event === 'step_update' && event.step_update?.step_type === 'tool') {
    const tool = safeLabel(event.step_update.tool_name) ?? 'unknown';
    const state = safeLabel(event.step_update.tool_info?.status ?? event.step_update.status);
    return {
      streamFilterVersion: 1, profile, kind: 'activity', activityKind: 'tool',
      summary: `正在执行工具：${tool}${state ? `（${state}）` : ''}`
    };
  }
  if (event?.event === 'step_update' && event.step_update?.step_type === 'agent_response') {
    const text = compactText(event.step_update.text_delta, MAX_ACTIVITY_CHARS);
    if (!text) return null;
    return {
      streamFilterVersion: 1, profile, kind: 'activity', activityKind: 'agent',
      summary: redactActivity(text), append: true
    };
  }
  if (event?.type === 'item.started' || event?.event === 'item.started') {
    const itemType = safeLabel(event.item?.type ?? event.item_type ?? event.type) ?? 'item';
    return { streamFilterVersion: 1, profile, kind: 'activity', activityKind: 'phase', summary: `开始：${itemType}` };
  }
  return null;
}

function eventLabel(event) {
  const labels = ['event', 'type', 'kind', 'status', 'subtype', 'say']
    .map(key => event?.[key])
    .filter(value => typeof value === 'string')
    .map(value => value.toLowerCase());
  return labels.find(label => /(result|complete|completion|final|done|success|failed|failure|error|fatal|init|started|session_created|task_started)/.test(label))
    ?? labels[0]
    ?? 'unknown';
}

function collectMetadata(value, result = {}, depth = 0) {
  if (!value || typeof value !== 'object' || depth > 4) return result;
  for (const [key, child] of Object.entries(value)) {
    if (ID_KEYS.has(key) && ['string', 'number'].includes(typeof child)) result[key] = child;
    else if ((key === 'cwd' || key === 'workspace') && typeof child === 'string') result[key] = child;
    else if (child && typeof child === 'object') collectMetadata(child, result, depth + 1);
  }
  return result;
}

function findSummary(event, maximum) {
  for (const key of TEXT_KEYS) {
    if (Object.hasOwn(event, key)) {
      const value = event[key];
      const summary = value && typeof value === 'object'
        ? findSummary(value, maximum)
        : compactText(value, maximum);
      if (summary) return summary;
    }
  }
  for (const value of Object.values(event)) {
    if (value && typeof value === 'object') {
      const summary = findSummary(value, maximum);
      if (summary) return summary;
    }
  }
  return null;
}

function normalizeEvent(event, profile, maximum) {
  const label = eventLabel(event);
  const metadata = collectMetadata(event);
  const status = typeof event.status === 'string'
    ? event.status
    : typeof event.result?.status === 'string' ? event.result.status : undefined;
  const normalizedStatus = status?.toLowerCase();
  if (/^(init|initialized|start|started|session_created|task_started)$/.test(label) || /(?:^|\.)(?:started|initialized)$/.test(label)) {
    return { streamFilterVersion: 1, profile, kind: 'init', event: label, ...metadata };
  }
  if (/(result|complete|completed|completion|final|done|success|failed|failure|error|fatal)/.test(label)) {
    const summary = findSummary(event, maximum);
    return {
      streamFilterVersion: 1,
      profile,
      kind: /(failed|failure|error|fatal)/.test(label) || ['failed', 'failure', 'error', 'fatal', 'canceled', 'interrupted', 'invalid'].includes(normalizedStatus) ? 'error' : 'terminal',
      event: label,
      ...(status ? { status } : {}),
      ...metadata,
      ...(summary ? { summary } : {})
    };
  }
  return null;
}

function emit(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

const { options, command, args } = parseArgs(process.argv.slice(2));
const child = spawn(command, args, { cwd: process.cwd(), env: process.env, stdio: ['pipe', 'pipe', 'pipe'] });
let suppressedEvents = 0;
let invalidLines = 0;
let terminalEvents = 0;
let stderr = '';

process.stdin.pipe(child.stdin);
const lines = readline.createInterface({ input: child.stdout, crlfDelay: Infinity });
lines.on('line', line => {
  if (!line.trim()) return;
  try {
    const event = JSON.parse(line);
    const normalized = normalizeActivity(event, options.profile)
      ?? normalizeEvent(event, options.profile, options.maxSummaryChars);
    if (normalized) {
      if (normalized.kind === 'terminal' || normalized.kind === 'error') terminalEvents += 1;
      emit(normalized);
    }
    else suppressedEvents += 1;
  } catch {
    invalidLines += 1;
  }
});

child.stderr.setEncoding('utf8');
child.stderr.on('data', chunk => {
  if (stderr.length < MAX_STDERR_CHARS) stderr += chunk.slice(0, MAX_STDERR_CHARS - stderr.length);
});

child.on('error', error => {
  emit({ streamFilterVersion: 1, profile: options.profile, kind: 'error', event: 'spawn-error', summary: compactText(error.message, options.maxSummaryChars) });
});

child.on('close', (code, signal) => {
  if ((code !== 0 || terminalEvents === 0) && stderr.trim()) {
    emit({ streamFilterVersion: 1, profile: options.profile, kind: 'error', event: 'stderr', summary: compactText(stderr, options.maxSummaryChars) });
  }
  emit({ streamFilterVersion: 1, profile: options.profile, kind: 'stream-summary', exitCode: code, ...(signal ? { signal } : {}), terminalEvents, suppressedEvents, invalidLines });
  process.exitCode = code ?? 1;
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => child.kill(signal));
}
