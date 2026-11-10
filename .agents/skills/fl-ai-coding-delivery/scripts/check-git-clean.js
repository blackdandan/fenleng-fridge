#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

function git(args) {
  return spawnSync('git', args, { encoding: 'utf8' });
}

if (git(['rev-parse', '--is-inside-work-tree']).status !== 0) process.exit(0);

const gitDirResult = git(['rev-parse', '--git-dir']);
if (gitDirResult.status !== 0) process.exit(0);

const gitDir = gitDirResult.stdout.trim();
if (
  fs.existsSync(path.join(gitDir, 'rebase-apply')) ||
  fs.existsSync(path.join(gitDir, 'rebase-merge')) ||
  fs.existsSync(path.join(gitDir, 'MERGE_HEAD'))
) {
  console.error('Blocked: the repository is in a merge or rebase conflict state.');
  process.exit(1);
}

const conflictDiff = git(['diff', "-G^(<<<<<<<|=======|>>>>>>>)", '--name-only']);
if (conflictDiff.status === 0 && conflictDiff.stdout.trim()) {
  console.error(`Blocked: unresolved conflict markers were detected in:\n${conflictDiff.stdout.trim()}`);
  process.exit(1);
}

process.exit(0);
