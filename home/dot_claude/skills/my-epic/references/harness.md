# Verification Harness Design

PR leaf は、成功をどう測るかを harness で説明するまで実装準備完了にしない。
Operation node は、何を、どこで実行し、何を証跡に成功と判断し、どう中止または rollback するかを runbook で説明するまで実行準備完了にしない。

## Gate 種別

### Test gate

leaf goal を証明する最小の自動テストを使う。E2E は cross-component behavior 自体が leaf goal の場合だけにする。exact command、pass 条件、既存または新規の test file path、既知の flake や環境要件を書く。

### Data gate

永続化、migration、backfill、analytics、permission、generated data に触れる場合は必須。migration dry-run、row-count や invariant の query、before/after sample、idempotency、backfill の checkpoint / resume、削除・retention のいずれかで確認する。

### Smoke gate

local または staging 起動後に新しい経路を通す最小の現実的 scenario を使う。CLI なら expected stdout、HTTP なら status と response shape、UI なら exact interaction と visible result、worker / job なら log line と side effect を期待値にする。

「手で確認する」だけにしない。手動観察が避けられない場合も、exact screen、input、expected result を定義する。

### Observability gate

production risk がある変更では必須。metric 名、log event と field、trace span または audit record、確認する alert / dashboard を指定する。

### Rollout / rollback gate

all-at-once ではない rollout では必須。feature flag または config 名、default 値、有効化の順序、rollback command または revert plan、cleanup PR の trigger を指定する。

### Operational execution gate

migration、backfill、initial script、feature flag 変更、external console 作業、cleanup など operation node では必須。次を指定する。

- Exact command or manual action
- Target environment, account, project, region, tenant, or service
- Executor / owner、承認者、実行してよい時間帯
- Required credentials or permissions
- Preconditions and dependency nodes
- Dry-run, preview, backup, or snapshot step when relevant
- Expected evidence: output, log line, row count, dashboard, metric, trace, or audit record
- Abort condition
- Rollback command or manual recovery action
- Irreversible effects

「手で実行する」で置き換えない。手動実行が必要な場合も、exact screen、field、value、action、expected evidence を定義する。前提 node が完了し、これらがすべて埋まり、ユーザー承認が記録されるまで operation を実行しない。

## Harness-first rule

以下のいずれかに該当し、対象実装 leaf に含めると独立した merge 順序または review 境界を失う場合だけ、実装 PR より前に separate Harness PR を作る。

- 必要な test が存在せず、複数 leaf で再利用される
- Contract behavior が不明
- Data validation に reusable script や fixture が必要
- Smoke testing に新しい local / staging tooling が必要

1 つの実装 leaf だけが使う test、fixture、script、tooling は、同じ leaf に含める。Acceptance criteria を弱めて、harness 不足を隠さない。

## PR leaf ready checklist

実装前に各 leaf が答えること。

- どの exact command が code path を証明するか
- どの exact data invariant が成立すべきか
- どの exact smoke scenario が feature path を証明するか
- どの file を create / modify / test してよく、どの file に触れてはいけないか
- どの review check で spec compliance と code quality を確認するか
- rollback、feature flag、cleanup をどう扱うか
- 何が起きたら PR creation を block するか
- PR body に貼る evidence は何か
