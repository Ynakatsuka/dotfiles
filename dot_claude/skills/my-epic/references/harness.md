# Verification Harness Design

PR leaf は、成功をどう測るかを harness で説明するまで実装準備完了にしない。
Operation node は、何を、どこで実行し、何を証跡に成功と判断し、どう中止または rollback するかを runbook で説明するまで実行準備完了にしない。

## Gate categories（gate 種別）

### Test gate（テスト）

leaf goal を証明する最小の自動テストを使う。

- Pure logic: unit test
- Boundary behavior: integration test
- Public API / event / schema compatibility: contract test
- Cross-component behavior が leaf goal の場合だけ E2E test

すべての Test gate に以下を含める。

- Exact command
- Expected pass condition
- Existing test files or new test file path
- Known flakes or environment requirements

### Data gate（データ）

永続化、migration、backfill、analytics、permission、generated data に触れる場合は必須。

以下のいずれかを指定する。

- Migration dry-run command
- Row-count or invariant query
- Before/after sample check
- Idempotency check
- Backfill checkpoint / resume check
- Data deletion or retention check

BigQuery や高コスト query では、current project / account を表示し、先に dry-run を実行する。

### Smoke gate（スモーク）

local または staging 起動後に新しい経路を通す最小の現実的 scenario を使う。

良い Smoke gate:

- Expected stdout を持つ CLI command
- Expected status / response shape を持つ HTTP request
- Exact interaction と expected visible result を持つ UI route
- Expected log line と side effect を持つ worker / job invocation

「手で確認する」だけにしない。手動観察が避けられない場合も、exact screen、input、expected result を定義する。

### Observability gate（観測）

production risk がある変更では必須。

以下を指定する。

- New or existing metric name
- Log event and fields
- Trace span or audit record
- Alert or dashboard to inspect

### Rollout / rollback gate（展開 / 戻し）

all-at-once ではない rollout の場合は必須。

以下を指定する。

- Feature flag or config name
- Default value
- Enablement sequence
- Rollback command or revert plan
- Cleanup PR trigger

### Operational execution gate（運用実行）

migration、backfill、initial script execution、feature flag change、external console work、cleanup、その他 operation node では必須。

以下を指定する。

- Exact command or manual action
- Target environment, account, project, region, tenant, or service
- Executor / owner
- Required credentials or permissions
- Preconditions and dependency nodes
- Dry-run, preview, backup, or snapshot step when relevant
- Expected evidence: output, log line, row count, dashboard, metric, trace, or audit record
- Abort condition
- Rollback command or manual recovery action
- Irreversible effects

operation gate を「手で実行する」で置き換えない。手動実行が必要な場合も、exact screen、field、value、action、expected evidence を定義する。

## Harness-first rule（harness 優先）

以下の場合は、実装 PR より前に separate Harness PR を作る。

- 必要な test が存在せず、複数 leaf で再利用される
- Contract behavior が不明
- Data validation に reusable script や fixture が必要
- Smoke testing に新しい local / staging tooling が必要

Acceptance criteria を弱めて、harness 不足を隠さない。

## PR leaf ready checklist（PR leaf 準備完了 checklist）

実装前に各 leaf が答えること。

- どの exact command が code path を証明するか
- どの exact data invariant が成立すべきか
- どの exact smoke scenario が feature path を証明するか
- どの file を create / modify / test してよく、どの file に触れてはいけないか
- Code quality cleanup 前に、どの review check で spec compliance を証明するか
- 何が起きたら PR creation を block するか
- PR body に貼る evidence は何か

## Operation node ready checklist（operation node 準備完了 checklist）

実行前に各 operation node が答えること。

- どの exact command or manual action を実行するか
- どの environment、account、project、region、tenant、service に触るか
- 誰が execution と approval を持つか
- どの dependency PR leaf or operation node が完了している必要があるか
- どの dry-run、preview、backup、snapshot が readiness を証明するか
- どの output、data invariant、log、metric、trace、dashboard、audit record が成功を証明するか
- どの condition で abort or rollback するか
- どの rollback or recovery action が使えるか
- どの evidence を operation file に記録するか
