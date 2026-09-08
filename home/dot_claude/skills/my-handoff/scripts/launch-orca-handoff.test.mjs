import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const script = fileURLToPath(new URL('./launch-orca-handoff.sh', import.meta.url));
const fakeOrca = (root, scenario) => `#!/usr/bin/env node
const { appendFileSync, writeFileSync } = require('node:fs');
const { execFileSync } = require('node:child_process');
const { join } = require('node:path');
const args = process.argv.slice(2);
const command = args.slice(0, 2).join(' ');
const get = flag => args[args.indexOf(flag) + 1];
const root = ${JSON.stringify(root)};
const scenario = ${JSON.stringify(scenario)};
appendFileSync(join(root, 'calls'), JSON.stringify(args) + '\\n');
const ok = result => process.stdout.write(JSON.stringify({ ok: true, result }));
if (command === 'status --json') {
  ok({ target: { kind: 'local' }, runtime: { reachable: true, state: scenario === 'unready' ? 'starting' : 'ready' } });
} else if (command === 'worktree show') {
  ok({ worktree: { id: 'repo-1::' + process.cwd(), repoId: 'repo-1', path: process.cwd() } });
} else if (command === 'worktree create') {
  if (scenario === 'malformed') { process.stdout.write('not json'); process.exit(0); }
  const name = get('--name');
  const route = join(root, name);
  execFileSync('git', ['worktree', 'add', '-q', '-b', name, route, args.includes('--base-branch') ? get('--base-branch') : 'main']);
  const result = { worktree: { id: 'repo-1::' + route, repoId: 'repo-1', path: route }, agentTerminalHandle: 'term-new' };
  if (scenario === 'no-handle') delete result.agentTerminalHandle;
  if (scenario === 'startup-warning') result.warning = 'agent failed to start';
  writeFileSync(join(root, 'delivered'), get('--prompt'));
  ok(result);
} else if (command === 'terminal create') {
  ok({ terminal: { handle: 'term-tab' } });
} else if (command === 'terminal wait') {
  if (scenario === 'wait-error') process.stdout.write(JSON.stringify({ ok: false, error: { message: 'readiness timed out' } }));
  else ok({ wait: { handle: 'term-tab', satisfied: scenario !== 'wait-unsatisfied', status: 'running' } });
} else if (command === 'terminal send') {
  if (scenario === 'send-error') process.stdout.write(JSON.stringify({ ok: false, error: { message: 'delivery unknown' } }));
  else if (scenario === 'send-refused') ok({ send: { handle: 'term-tab', accepted: false, bytesWritten: 0 } });
  else { writeFileSync(join(root, 'delivered'), get('--text')); ok({ send: { handle: 'term-tab', accepted: true, bytesWritten: 100 } }); }
} else { process.stderr.write('unexpected command: ' + command); process.exit(2); }
`;

function fixture(t, scenario = 'success') {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'handoff-test-')));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const repo = join(root, 'source');
  mkdirSync(repo);
  const cli = join(root, 'orca-test');
  writeFileSync(cli, fakeOrca(root, scenario), { mode: 0o700 });
  const env = { ...process.env };
  for (const key of Object.keys(env)) {
    if (key.startsWith('GIT_') || key.startsWith('ORCA_')) delete env[key];
  }
  Object.assign(env, {
    GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_NOSYSTEM: '1',
    GIT_AUTHOR_NAME: 'Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
    GIT_COMMITTER_NAME: 'Fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid',
    ORCA_CLI_COMMAND: cli,
  });
  const git = (...args) => execFileSync('git', args, { cwd: repo, env, encoding: 'utf8' }).trim();
  git('init', '-q', '--initial-branch=main');
  git('-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false', 'commit', '-q', '--allow-empty', '-m', 'test fixture');
  const run = (options = [], input = '依頼: 対象を調査。完了条件: 根拠と結論を回答。') => spawnSync(
    'bash', [script, '--name', 'handoff-topic', '--agent', 'codex', ...options],
    { cwd: repo, env, input, encoding: 'utf8' },
  );
  const calls = () => readFileSync(join(root, 'calls'), 'utf8').trim().split('\n').map(JSON.parse);
  return { root, repo, env, git, run, calls };
}

test('a new independent worktree receives the literal brief once; the parent branch stays unchanged', t => {
  const f = fixture(t);
  f.git('switch', '-q', '-c', 'parent-topic');
  f.git('-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false', 'commit', '-q', '--allow-empty', '-m', 'parent work');
  const marker = join(f.root, 'must-not-exist');
  const brief = `依頼: 引用符 ' \\" と改行\n\$(touch ${marker}) とバッククォート \`touch ${marker}\` を保持する。`;
  const result = f.run([], brief);
  assert.equal(result.status, 0, result.stderr);
  const output = JSON.parse(result.stdout);
  assert.equal(output.status, 'prompt_sent');
  assert.equal(output.mode, 'worktree');
  assert.equal(output.terminal, 'term-new');
  assert.ok(output.worktree.endsWith('/' + output.name));
  assert.equal(f.git('branch', '--show-current'), 'parent-topic');
  assert.equal(f.git('rev-parse', output.name), f.git('rev-parse', 'main'));
  assert.notEqual(f.git('rev-parse', output.name), f.git('rev-parse', 'HEAD'));
  assert.ok(readFileSync(join(f.root, 'delivered'), 'utf8').endsWith(brief));
  assert.throws(() => readFileSync(marker), { code: 'ENOENT' });
  const mutations = f.calls().filter(args => args[1] === 'create' || args[1] === 'send');
  assert.equal(mutations.length, 1);
  assert.ok(mutations[0].includes('--no-parent'));
  assert.equal(mutations[0][mutations[0].indexOf('--repo') + 1], 'id:repo-1');
  assert.ok(!result.stdout.includes(brief));
  assert.ok(result.stdout.length < 700);
});

test('repeated topic names automatically create distinct branches', t => {
  const f = fixture(t);
  const first = f.run();
  const second = f.run();
  assert.equal(first.status, 0, first.stderr);
  assert.equal(second.status, 0, second.stderr);
  assert.notEqual(JSON.parse(first.stdout).worktree, JSON.parse(second.stdout).worktree);
});

test('a tab uses the complete source id and sends only after readiness', t => {
  const f = fixture(t);
  const result = f.run(['--tab']);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).worktree, 'repo-1::' + f.repo);
  const operations = f.calls().filter(args => args[0] === 'terminal');
  assert.deepEqual(operations.map(args => args[1]), ['create', 'wait', 'send']);
  assert.equal(operations[0][operations[0].indexOf('--worktree') + 1], 'id:repo-1::' + f.repo);
  for (const args of operations.slice(1)) assert.equal(args[args.indexOf('--terminal') + 1], 'term-tab');
});

test('current-commit handoffs reject local-only changes before contacting Orca', t => {
  const f = fixture(t);
  writeFileSync(join(f.repo, 'unfinished.txt'), 'local work');
  const result = f.run(['--base-branch', 'HEAD']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /uncommitted changes/);
  assert.throws(() => f.calls(), { code: 'ENOENT' });
});

test('an explicit base is resolved to a commit before worktree creation', t => {
  const f = fixture(t);
  const sha = f.git('rev-parse', 'HEAD');
  const result = f.run(['--base-branch', 'HEAD']);
  assert.equal(result.status, 0, result.stderr);
  const create = f.calls().find(args => args[0] === 'worktree' && args[1] === 'create');
  assert.equal(create[create.indexOf('--base-branch') + 1], sha);
});

for (const scenario of ['unready', 'malformed', 'no-handle', 'startup-warning', 'wait-error', 'wait-unsatisfied', 'send-error', 'send-refused']) {
  test(`${scenario} is an error and never triggers a duplicate creation or send`, t => {
    const f = fixture(t, scenario);
    const isTab = scenario.startsWith('wait-') || scenario.startsWith('send-');
    const result = f.run(isTab ? ['--tab'] : []);
    assert.notEqual(result.status, 0);
    assert.equal(result.stdout, '');
    const calls = f.calls();
    assert.ok(calls.filter(args => args[1] === 'create').length <= 1);
    assert.ok(calls.filter(args => args[1] === 'send').length <= 1);
    if (scenario.startsWith('wait-')) assert.ok(!calls.some(args => args[1] === 'send'));
    if (scenario === 'unready') assert.ok(!calls.some(args => args[1] === 'create'));
    if (scenario === 'no-handle' || scenario === 'startup-warning' || isTab) assert.match(result.stderr, /worktree=repo-1::/);
    if (isTab) assert.match(result.stderr, /terminal=term-tab/);
  });
}
