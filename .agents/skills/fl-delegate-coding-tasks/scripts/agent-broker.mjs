#!/usr/bin/env node

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const DEFAULT_PROBE_TIMEOUT = 60;
const DEFAULT_PROBE_TTL = 300;
const DEFAULT_PROBE_ATTEMPTS = 2;
const PROBE_SCHEMA_VERSION = 2;
const SCRIPT_ROOT = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_REGISTRY = path.resolve(SCRIPT_ROOT, '../references/executors.json');
const DEFAULT_TASK_CATALOG = path.resolve(SCRIPT_ROOT, '../references/delegation-task-catalog.json');
const RISK_LEVELS = ['low', 'medium', 'high', 'critical'];
const TASK_MODES = ['read-only', 'write', 'verification', 'review'];

class UsageError extends Error {
  constructor(message) {
    super(message);
    this.name = 'UsageError';
    this.exitCode = 2;
  }
}

function parseArgs(argv) {
  const action = argv[0] ?? 'help';
  const options = {};
  for (let index = 1; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith('--')) throw new UsageError(`不支持的位置参数：${key}`);
    if (Object.hasOwn(options, key)) throw new UsageError(`参数不能重复：${key}`);
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) throw new UsageError(`参数缺少值：${key}`);
    options[key] = value;
    index += 1;
  }
  return { action, options };
}

function required(options, name) {
  if (!options[name]) throw new UsageError(`${name} 必填`);
  return options[name];
}

function integer(value, field, minimum, maximum) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < minimum || parsed > maximum) throw new UsageError(`${field} 必须是 ${minimum} 到 ${maximum} 的整数`);
  return parsed;
}

function boolean(value, field) {
  if (value === undefined) return false;
  if (value === 'true') return true;
  if (value === 'false') return false;
  throw new UsageError(`${field} 必须是 true 或 false`);
}

export function projectRoot(value) {
  const root = fs.realpathSync(path.resolve(value));
  const result = spawnSync('git', ['rev-parse', '--show-toplevel'], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  const discovered = result.status === 0 ? fs.realpathSync(path.resolve(result.stdout.trim())) : null;
  if (discovered !== root) throw new UsageError('--project 必须是 Git 主工作目录根路径');
  return root;
}

function workspace(project) {
  const root = projectRoot(project);
  const cwd = fs.realpathSync(process.cwd());
  if (cwd !== root) throw new UsageError(`当前宿主工作目录与目标项目不一致：cwd=${cwd} project=${root}`);
  return { schemaVersion: 1, status: 'ready', workspace: root, cwd, gitRoot: root };
}

function readJson(file, label = path.basename(file)) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    throw new UsageError(`${label} 不是可读取的 JSON：${file}`);
  }
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const temporary = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporary, file);
}

function stringArray(value) {
  return Array.isArray(value) && value.every(item => typeof item === 'string');
}

export function loadTaskCatalog(catalogFile = DEFAULT_TASK_CATALOG) {
  const file = path.resolve(catalogFile);
  const catalog = readJson(file, 'delegation task catalog');
  if (catalog.schemaVersion !== 1 || !Array.isArray(catalog.tasks) || !Array.isArray(catalog.riskLevels)) {
    throw new UsageError('delegation task catalog 必须声明 schemaVersion=1、riskLevels 和 tasks');
  }
  if (catalog.riskLevels.join('\0') !== RISK_LEVELS.join('\0')) throw new UsageError(`task catalog riskLevels 必须为 ${RISK_LEVELS.join(', ')}`);
  const ids = new Set();
  for (const task of catalog.tasks) {
    if (!task || typeof task.id !== 'string' || !task.id.trim() || ids.has(task.id)) throw new UsageError('每个 delegation task 必须有唯一的非空 id');
    ids.add(task.id);
    if (typeof task.category !== 'string' || !task.category.trim()) throw new UsageError(`${task.id}: category 不能为空`);
    if (!TASK_MODES.includes(task.mode)) throw new UsageError(`${task.id}: mode 必须为 ${TASK_MODES.join(', ')}`);
    if (!RISK_LEVELS.includes(task.defaultRisk)) throw new UsageError(`${task.id}: defaultRisk 必须为 ${RISK_LEVELS.join(', ')}`);
    if (typeof task.summary !== 'string' || !task.summary.trim()) throw new UsageError(`${task.id}: summary 不能为空`);
  }
  return { file, catalog };
}

export function loadRegistry(registryFile = DEFAULT_REGISTRY) {
  const file = path.resolve(registryFile);
  const registry = readJson(file, 'executor registry');
  if (registry.schemaVersion !== 1 || !Array.isArray(registry.executors)) throw new UsageError('executor registry 必须声明 schemaVersion=1 和 executors 数组');
  const ids = new Set();
  for (const entry of registry.executors) {
    if (!entry || typeof entry.id !== 'string' || !entry.id.trim() || ids.has(entry.id)) throw new UsageError('每个 executor 必须有唯一的非空 id');
    ids.add(entry.id);
    if (typeof entry.enabled !== 'boolean' || typeof entry.command !== 'string' || !entry.command.trim()) throw new UsageError(`${entry.id}: enabled 必须为布尔值且 command 不能为空`);
    if (![null, undefined].includes(entry.model) && typeof entry.model !== 'string') throw new UsageError(`${entry.id}: model 必须是字符串或 null`);
    if (![null, undefined].includes(entry.reasoningEffort) && typeof entry.reasoningEffort !== 'string') throw new UsageError(`${entry.id}: reasoningEffort 必须是字符串或 null`);
    if (!stringArray(entry.suitableTasks) || !stringArray(entry.avoidTasks)) throw new UsageError(`${entry.id}: suitableTasks 和 avoidTasks 必须是字符串数组`);
    if (!stringArray(entry.supportedCategories) || !entry.supportedCategories.length) throw new UsageError(`${entry.id}: supportedCategories 必须是非空字符串数组`);
    if (!stringArray(entry.preferredTaskTypes)) throw new UsageError(`${entry.id}: preferredTaskTypes 必须是字符串数组`);
    if (!RISK_LEVELS.includes(entry.riskLimit)) throw new UsageError(`${entry.id}: riskLimit 必须为 ${RISK_LEVELS.join(', ')}`);
    if (entry.selectionPriority !== undefined && (!Number.isInteger(entry.selectionPriority) || entry.selectionPriority < 0 || entry.selectionPriority > 1000)) {
      throw new UsageError(`${entry.id}: selectionPriority 必须是 0 到 1000 的整数`);
    }
    if (entry.fallbackFor !== undefined && !stringArray(entry.fallbackFor)) throw new UsageError(`${entry.id}: fallbackFor 必须是字符串数组`);
    if (!entry.session || typeof entry.session.strategy !== 'string' || !stringArray(entry.session.startArgs)) throw new UsageError(`${entry.id}: session.strategy 和 session.startArgs 必填`);
    if (!entry.session.outputFilter || typeof entry.session.outputFilter.script !== 'string' || typeof entry.session.outputFilter.profile !== 'string'
      || !Number.isInteger(entry.session.outputFilter.maxSummaryChars) || entry.session.outputFilter.maxSummaryChars < 200 || entry.session.outputFilter.maxSummaryChars > 8000) {
      throw new UsageError(`${entry.id}: session.outputFilter 必须声明 script、profile 和 200..8000 的 maxSummaryChars`);
    }
    if (!entry.probe || !stringArray(entry.probe.versionArgs) || !stringArray(entry.probe.connectivityArgs)) throw new UsageError(`${entry.id}: probe.versionArgs 和 probe.connectivityArgs 必填`);
  }
  return { file, registry };
}

export function resolveCommand(command) {
  if (!command) return null;
  if (command.includes(path.sep)) return fs.existsSync(command) ? command : null;
  const extensions = process.platform === 'win32'
    ? ['', ...(process.env.PATHEXT ?? '.COM;.EXE;.BAT;.CMD').split(';').map(extension => extension.toLowerCase())]
    : [''];
  for (const directory of (process.env.PATH ?? '').split(path.delimiter)) {
    for (const extension of extensions) {
      const candidate = path.join(directory, `${command}${extension}`);
      if (fs.existsSync(candidate)) return candidate;
    }
  }
  return null;
}

export function substitute(value, entry, project, timeoutSeconds) {
  return value
    .replaceAll('${PROJECT}', project)
    .replaceAll('${TIMEOUT}', String(timeoutSeconds))
    .replaceAll('${MODEL}', entry.model ?? '')
    .replaceAll('${REASONING_EFFORT}', entry.reasoningEffort ?? '');
}

function runProbeCommand(command, args, cwd, timeoutSeconds) {
  const started = Date.now();
  const result = spawnSync(command, args, { cwd, encoding: 'utf8', timeout: timeoutSeconds * 1000, maxBuffer: 2 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'] });
  return { ...result, durationMs: Date.now() - started };
}

function safeVersion(result) {
  return `${result.stdout ?? ''}\n${result.stderr ?? ''}`.split(/\r?\n/).map(value => value.trim()).find(Boolean)?.slice(0, 120) ?? null;
}

function probeFailure(result) {
  if (result.error?.code === 'ETIMEDOUT') return 'probe_timed_out';
  const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
  if (/authentication fails?|authentication failed|authentication required|unauthorized|forbidden|invalid api key|missing api key|not logged in|credential|governor/i.test(output)) return 'authentication_failed';
  if (/network error|econnrefused|econnreset|enotfound|dns|unable to connect|connection (?:failed|timed out)|fetch failed/i.test(output)) return 'network_unreachable';
  return result.status !== 0 || result.error ? 'probe_failed' : null;
}

function probeCacheFile(project, entry) {
  const key = crypto.createHash('sha256').update(`${project}\0${JSON.stringify(entry)}`).digest('hex');
  return path.join(os.tmpdir(), 'fenleng-agent-probes', `${key}.json`);
}

export function probeExecutor(project, executorId, registryFile, options = {}) {
  const ttl = integer(options.ttlSeconds ?? DEFAULT_PROBE_TTL, 'probe ttl', 0, 3600);
  const timeout = integer(options.timeoutSeconds ?? DEFAULT_PROBE_TIMEOUT, 'probe timeout', 1, 120);
  const maximumAttempts = integer(options.attempts ?? DEFAULT_PROBE_ATTEMPTS, 'probe attempts', 1, 3);
  const { registry } = loadRegistry(registryFile);
  const entry = registry.executors.find(candidate => candidate.id === executorId);
  if (!entry) throw new UsageError(`注册表中不存在执行器：${executorId}`);
  const cacheFile = probeCacheFile(project, entry);
  if (ttl > 0 && entry.enabled && fs.existsSync(cacheFile)) {
    const cached = readJson(cacheFile, 'probe cache');
    if (cached.schemaVersion === PROBE_SCHEMA_VERSION && cached.workspace === project && cached.usable
      && Date.now() - Date.parse(cached.checkedAt) <= ttl * 1000) return { ...cached, cached: true };
  }
  const resolved = resolveCommand(entry.command);
  const base = {
    schemaVersion: PROBE_SCHEMA_VERSION,
    executor: entry.id,
    workspace: project,
    installed: Boolean(resolved),
    version: null,
    authenticated: null,
    reachable: null,
    usable: false,
    checkedAt: new Date().toISOString(),
    durationMs: 0,
    attempts: 0,
    failureCode: null,
    cached: false
  };
  if (!entry.enabled) return { ...base, failureCode: 'disabled' };
  if (!resolved) return { ...base, failureCode: 'not_installed' };
  const versionArgs = entry.probe.versionArgs.map(value => substitute(value, entry, project, timeout));
  const connectivityArgs = entry.probe.connectivityArgs.map(value => substitute(value, entry, project, timeout));
  const versionResult = runProbeCommand(resolved, versionArgs, project, timeout);
  base.durationMs += versionResult.durationMs;
  base.version = safeVersion(versionResult);
  if (versionResult.status !== 0 || versionResult.error) return { ...base, failureCode: versionResult.error?.code === 'ETIMEDOUT' ? 'probe_timed_out' : 'version_failed' };
  let failureCode;
  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    const connectivity = runProbeCommand(resolved, connectivityArgs, project, timeout);
    base.attempts = attempt;
    base.durationMs += connectivity.durationMs;
    const output = `${connectivity.stdout ?? ''}${connectivity.stderr ?? ''}`;
    failureCode = probeFailure(connectivity)
      ?? (entry.probe.expectOutput === true && !output.trim() ? 'probe_failed' : null)
      ?? (typeof entry.probe.expectedReply === 'string' && !new RegExp(`\\b${entry.probe.expectedReply}\\b`, 'i').test(output) ? 'probe_failed' : null);
    if (!failureCode || failureCode === 'authentication_failed') break;
  }
  if (failureCode) return {
    ...base,
    authenticated: failureCode === 'authentication_failed' ? false : null,
    reachable: failureCode === 'authentication_failed' ? true : failureCode === 'network_unreachable' || failureCode === 'probe_timed_out' ? false : null,
    failureCode
  };
  const result = { ...base, authenticated: true, reachable: true, usable: true };
  writeJson(cacheFile, result);
  return result;
}

function capabilities(registryFile) {
  const { file, registry } = loadRegistry(registryFile);
  return {
    schemaVersion: 2,
    registry: file,
    probeLevel: 'installed-only',
    executionMode: 'host-managed-session',
    executors: registry.executors.map(entry => ({
      id: entry.id,
      enabled: entry.enabled,
      available: resolveCommand(entry.command) !== null,
      command: entry.command,
      model: entry.model ?? null,
      reasoningEffort: entry.reasoningEffort ?? null,
      suitableTasks: entry.suitableTasks,
      avoidTasks: entry.avoidTasks,
      supportedCategories: entry.supportedCategories,
      preferredTaskTypes: entry.preferredTaskTypes,
      riskLimit: entry.riskLimit,
      selectionPriority: entry.selectionPriority ?? 0,
      fallbackFor: entry.fallbackFor ?? [],
      capabilityReference: entry.capabilityReference ?? null,
      capabilities: entry.capabilities ?? {},
      session: entry.session
    }))
  };
}

function executorConfig(executorId, registryFile) {
  const { registry } = loadRegistry(registryFile);
  const entry = registry.executors.find(candidate => candidate.id === executorId);
  if (!entry) throw new UsageError(`注册表中不存在执行器：${executorId}`);
  return {
    schemaVersion: 1,
    id: entry.id,
    enabled: entry.enabled,
    available: resolveCommand(entry.command) !== null,
    command: entry.command,
    ...(entry.model ? { model: entry.model } : {}),
    ...(entry.reasoningEffort ? { reasoningEffort: entry.reasoningEffort } : {}),
    session: entry.session,
    ...(entry.capabilityReference ? { capabilityReference: entry.capabilityReference } : {})
  };
}

function catalogTasks(category, taskId, catalogFile) {
  if (Boolean(category) === Boolean(taskId)) throw new UsageError('tasks 必须且只能提供 --category 或 --id');
  const { catalog } = loadTaskCatalog(catalogFile);
  const tasks = taskId
    ? catalog.tasks.filter(task => task.id === taskId)
    : catalog.tasks.filter(task => task.category === category);
  if (!tasks.length) throw new UsageError(taskId ? `任务目录中不存在 task type：${taskId}` : `任务目录中不存在 category：${category}`);
  return {
    schemaVersion: 1,
    ...(category ? { category } : {}),
    tasks: tasks.map(task => ({ id: task.id, mode: task.mode, defaultRisk: task.defaultRisk, summary: task.summary }))
  };
}

export function routeTask(taskType, requestedRisk, registryFile, catalogFile, options = {}) {
  const { file: registryPath, registry } = loadRegistry(registryFile);
  const { file: catalogPath, catalog } = loadTaskCatalog(catalogFile);
  const task = catalog.tasks.find(candidate => candidate.id === taskType);
  if (!task) throw new UsageError(`任务目录中不存在 task type：${taskType}`);
  const risk = requestedRisk ?? task.defaultRisk;
  if (!RISK_LEVELS.includes(risk)) throw new UsageError(`--risk 必须为 ${RISK_LEVELS.join(', ')}`);
  const limit = integer(options.limit ?? 3, 'route limit', 1, 5);
  const explain = boolean(options.explain, '--explain');
  const candidates = [];
  const rejected = [];
  for (const entry of registry.executors) {
    const reasons = [];
    const available = resolveCommand(entry.command) !== null;
    if (!entry.enabled) reasons.push('disabled');
    if (!available) reasons.push('not-installed');
    if (!entry.supportedCategories.includes(task.category)) reasons.push('unsupported-category');
    if (RISK_LEVELS.indexOf(risk) > RISK_LEVELS.indexOf(entry.riskLimit)) reasons.push('risk-limit-exceeded');
    if (task.mode === 'write' && entry.capabilities?.canWrite !== true) reasons.push('write-unsupported');
    if (task.mode === 'verification' && entry.capabilities?.canRunTests !== true) reasons.push('verification-unsupported');
    if (task.mode === 'review' && entry.capabilities?.canReview !== true) reasons.push('review-unsupported');
    if (reasons.length) {
      rejected.push({ id: entry.id, reasons });
      continue;
    }
    const preferred = entry.preferredTaskTypes.includes(task.id);
    candidates.push({
      id: entry.id,
      preference: preferred ? 'preferred' : 'supported',
      score: preferred ? 0 : 1,
      selectionPriority: entry.selectionPriority ?? 0,
      sessionStrategy: entry.session.strategy,
      ...(entry.model ? { model: entry.model } : {}),
      ...(entry.reasoningEffort ? { reasoningEffort: entry.reasoningEffort } : {})
    });
  }
  candidates.sort((left, right) => left.score - right.score || right.selectionPriority - left.selectionPriority || left.id.localeCompare(right.id));
  const result = {
    schemaVersion: 1,
    task: { id: task.id, category: task.category, mode: task.mode, risk },
    candidates: candidates.slice(0, limit).map(({ score, ...candidate }) => candidate),
    eligibleCount: candidates.length,
    rejectedCount: rejected.length,
    decisionOwner: 'current-session-orchestrator'
  };
  if (explain || !candidates.length) return { ...result, registry: registryPath, catalog: catalogPath, rejected };
  return result;
}

function help() {
  return {
    usage: 'agent-broker <capabilities|tasks|route|executor|workspace|probe> [options]',
    commands: {
      capabilities: '[--registry executors.json]',
      tasks: '--category <name> | --id <task-id> [--catalog delegation-task-catalog.json]',
      route: '--task-type <id> [--risk <level>] [--limit <1-5>] [--explain true|false] [--registry executors.json] [--catalog delegation-task-catalog.json]',
      executor: '--id <executor-id> [--registry executors.json]',
      workspace: '--project <root>',
      probe: '--project <root> --executor <id> [--registry executors.json] [--timeout <seconds>] [--ttl <seconds>] [--attempts <count>]'
    },
    note: 'route 只过滤并排序候选执行器，最终选择和审批属于当前会话主编排者；Broker 不创建隔离 Git 结构。'
  };
}

export function main(argv = process.argv.slice(2)) {
  const { action, options } = parseArgs(argv);
  if (action === 'help' || action === '--help') return help();
  if (action === 'capabilities') return capabilities(options['--registry']);
  if (action === 'tasks') return catalogTasks(options['--category'], options['--id'], options['--catalog']);
  if (action === 'route') return routeTask(required(options, '--task-type'), options['--risk'], options['--registry'], options['--catalog'], {
    limit: options['--limit'],
    explain: options['--explain']
  });
  if (action === 'executor') return executorConfig(required(options, '--id'), options['--registry']);
  if (action === 'workspace') return workspace(required(options, '--project'));
  if (action === 'probe') {
    const project = projectRoot(required(options, '--project'));
    return probeExecutor(project, required(options, '--executor'), options['--registry'], {
      timeoutSeconds: options['--timeout'],
      ttlSeconds: options['--ttl'],
      attempts: options['--attempts']
    });
  }
  throw new UsageError(`未知命令：${action}`);
}

const direct = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
if (direct) {
  try {
    process.stdout.write(`${JSON.stringify(main(), null, 2)}\n`);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = error.exitCode ?? 1;
  }
}
