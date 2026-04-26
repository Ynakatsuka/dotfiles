# Senior/Staff Engineer Review Checklist

Phase 1-0 (Investigation) の調査範囲、Phase 1-3 (Design) で `design.md` に反映すべき観点、Phase 1-4 (External Review) のレビュープロンプトの根拠として使う。

設計時は全観点について「触れた／触れない理由がある」状態にする。`design.md` には少なくとも `Risks & Mitigations`, `Rejected alternatives`, `Open Questions` を必ず含める。

## Phase 1-0: 事前調査で必ず行うこと

時間は十分かけてよい。`Explore` subagent で並列調査を活用する。「コードで分かることは聞かない」を徹底し、結果を Phase 1-1 の質問削減と Phase 1-3 の設計判断材料に使う。

### A. 一般調査

- [ ] 関連既存コード（類似機能・呼び出し元・テスト）
- [ ] 関連 ADR / PRD / 過去 PR / issue / 設計ドキュメント
- [ ] 依存ライブラリのバージョンと主要 API（fast-moving topics は live source で確認）
- [ ] CI / lint / test / formatter の規約
- [ ] 既存の運用観測基盤（ログ・メトリクス・アラート）

### B. コードベース整合性のための調査（セクション 10 の根拠を集める）

- [ ] **同種実装の網羅検索**: ユースケース・ドメイン名・キーワードで grep / ast-grep し、類似実装を全部洗い出す
- [ ] **呼び出しグラフ**: 触ろうとしている共有 helper / shared module / 公開 type の callers / consumers を列挙
- [ ] **規約の現物確認**: 命名・error class・log key・metric name・config key・feature flag 命名・i18n key の既存例を最低 2 件読む
- [ ] **テスト規約**: 既存 fixture / factory / mock 戦略・assertion 粒度・E2E vs unit の責務分担を確認
- [ ] **過去議論**: 類似 PR の設計議論、revert 履歴、postmortem、deprecated 通告
- [ ] **進行中マイグレーション**: 並走中の大規模リファクタ・移行の有無と、それを妨げないか
- [ ] **CI / 開発体験**: 既存 lint / pre-commit / generator / Docker Compose 等の前提

調査結果は `design.md` の「既存コードとの統合」「Codebase coherence」「Blast radius」セクションに具体的なファイルパス・モジュール名・PR 番号付きで反映する。

## 1. 失敗モードとエッジケース

- [ ] 入力の境界値・空値・nil/None・不正値・極端値
- [ ] タイムアウト、ネットワーク断、部分失敗
- [ ] リトライによる重複（idempotency キーや exactly-once 性）
- [ ] 競合・並行更新（race condition、ロック粒度、楽観/悲観）
- [ ] キャパシティ超過、レート制限、バックプレッシャ
- [ ] 順序保証が崩れた時の挙動
- [ ] クロックずれ、タイムゾーン、夏時間

## 2. 非機能要件 (NFR)

- [ ] レイテンシ目標（p50 / p95 / p99）
- [ ] スループット・QPS・同時接続数
- [ ] エラーバジェット・SLA / SLO
- [ ] コスト（インフラ・AI/外部 API 課金・帯域）
- [ ] ストレージ容量・成長見積もり

## 3. セキュリティ

- [ ] 認証 (authn) と認可 (authz) の境界
- [ ] PII / 機微情報の取り扱い・ログ出力からの除外
- [ ] シークレット管理（KMS、SOPS、age など）
- [ ] インジェクション（SQL / command / prompt / SSRF / XSS）
- [ ] 監査ログ・改ざん検知
- [ ] 最小権限の原則と権限境界

## 4. 運用・デプロイ

- [ ] ロールアウト戦略（feature flag / canary / blue-green）
- [ ] ロールバック手順（DB スキーマ変更を含む場合の戻し方）
- [ ] データ移行・バックフィル戦略・所要時間
- [ ] スキーマ進化と後方互換性
- [ ] 設定変更の伝搬と一貫性

## 5. 観測性

- [ ] メトリクス（業務 KPI / システム指標）
- [ ] ログ（粒度、PII 除去、構造化）
- [ ] アラート（閾値、対応手順、誰がオンコール）
- [ ] トレーシング・相関 ID

## 6. 契約と blast radius

- [ ] 公開 API / モジュール境界の契約
- [ ] 後方互換・破壊的変更の扱い
- [ ] upstream callers の影響範囲（誰が呼んでいるか）
- [ ] downstream consumers の影響範囲（誰に流れていくか）
- [ ] テスト・ドキュメント・スクリプト・運用手順への波及

## 7. 隠れた前提と不変条件

- [ ] 「常に成り立つ」と想定している不変条件を列挙
- [ ] それを保証する仕組み（型・テスト・assertion・コメント）
- [ ] 既存コードがその挙動を提供している前提なら、根拠を確認

## 8. 採用しなかった代替案

- [ ] 検討したが採用しなかった案を最低 2 つ
- [ ] それぞれの不採用理由
- [ ] どの条件が変われば採用に変わるか

## 9. 1-3 年後の後悔ポイント

- [ ] 規模が 10 倍になったら破綻する箇所
- [ ] チーム / オーナー変更で困る箇所
- [ ] 同種機能の追加で複雑化する箇所
- [ ] デバッグ困難になりそうな抽象化

## 10. 既存コードベースとの整合性 (Codebase Coherence)

一般論ではなくこのプロジェクト固有の事情に踏み込んで、新機能が既存コードの秩序・規約・既存実装と噛み合っているかを確認する。Phase 1-0 (Investigation) の調査結果を根拠に判断する。

### 10.1 重複・再利用・移行漏れ

- [ ] 同じ／似たユースケースを解く既存実装はないか（重複・分岐・統合機会）
- [ ] 類似機能との差分が「仕様上の意図」として説明されているか
- [ ] 既存共通 helper / shared module で解決できる課題に独自実装を重ねていないか
- [ ] 既存の API schema / DTO / serializer / 共通バリデータを重複定義していないか
- [ ] 同等機能を提供する旧 endpoint / batch / UI / job が残存していないか
- [ ] 新旧実装の coexistence 期間に二重書き込み・読み取り分岐が発生しないか
- [ ] コピペで bug fix 対象を増やしていないか（コピペ元の修正取りこぼしリスク）
- [ ] 「3 回の法則」を無視した早すぎる抽象化になっていないか
- [ ] 共通化しすぎて既存機能の例外的要件が表現できなくなっていないか
- [ ] 非同期処理／ジョブが既存ワーカー基盤に相乗りせず独自実装になっていないか

### 10.2 境界・抽象化・layer

- [ ] DDD 境界（Bounded Context / Aggregate）を侵害していないか
- [ ] application / domain / infrastructure の責務分離を崩していないか
- [ ] 既存 repository / service / usecase の粒度と一致しているか
- [ ] 既存 domain model に載せるべき概念を別 layer に逃がしていないか
- [ ] import boundary / package visibility を迂回していないか
- [ ] モジュール間の依存方向が layered / clean architecture の規約に反していないか
- [ ] 状態管理（DB・キャッシュ）の隠蔽レベルが既存データアクセス層のポリシーと一致しているか
- [ ] 認可ロジックの配置（基盤層 / アプリケーション層）が既存規約に沿っているか

### 10.3 命名・モデル・契約の一貫性

- [ ] クラス／メソッド／変数／DB テーブル名が既存命名規則・ユビキタス言語と一致しているか
- [ ] 同じ概念に別名を与えてモデルを分岐させていないか
- [ ] 既存の error class / error code / message format と整合しているか
- [ ] 既存の validation 体系と同じレイヤーで検証しているか
- [ ] retry / timeout / cancellation の扱いが類似機能と揃っているか
- [ ] 既存 enum / union / status machine に新状態を足す影響を確認しているか
- [ ] 発行するドメインイベントの粒度・命名規則が既存イベントスキーマ体系と調和しているか

### 10.4 設定・運用・観測体系との整合

- [ ] 環境変数 / config の命名・置き場所・override 優先順位と一致しているか
- [ ] ログ key 名・構造化形式・必須メタデータ（TraceID 等）が既存と一致しているか
- [ ] metrics の命名階層・label 設計が既存と一致しているか
- [ ] feature flag の粒度・命名・剥がしやすさが既存運用ルールと一致しているか
- [ ] cache key 設計と invalidation 戦略が既存と整合しているか
- [ ] queue / job / scheduler の実装パターンと一致しているか
- [ ] i18n key 設計・fallback 方針が既存ルールと一致しているか
- [ ] 既存の認可 policy / permission model を再利用しているか
- [ ] audit / activity log の出力対象と整合しているか
- [ ] notification / email / template の tone・variable 体系と一致しているか

### 10.5 データ・スキーマ・共有契約への波及

- [ ] 共有ライブラリ・ヘルパーのシグネチャ変更が全呼び出し元で意味を保っているか
- [ ] 公開 type / GraphQL / OpenAPI 拡張が同型を参照する別機能に副作用を出さないか
- [ ] 共有 DB テーブルへのカラム追加・インデックス変更が他サービスのクエリ性能・ORM に影響しないか
- [ ] 既存 DB schema の正規化方針・命名規則と一致しているか
- [ ] 類似 table / index / constraint の設計理由を確認しているか
- [ ] 既存 migration / seed / backfill の流儀に従っているか
- [ ] 新規 cache key が既存キー空間と衝突しないか

### 10.6 テスト・fixture・CI・DX

- [ ] 既存 fixture / factory / test helper を再利用しているか
- [ ] テスト戦略（AAA / mock 戦略 / assertion 粒度）が既存スイートと一貫しているか
- [ ] snapshot / golden file の更新範囲が意図した差分に限定されているか
- [ ] 既存 mocks / stubs の契約と本番実装の差を広げていないか
- [ ] 既存 E2E / integration test の責務を unit test に重複させていないか
- [ ] 既存 lint / formatter / typecheck / pre-commit / CI / codegen の前提を壊していないか
- [ ] CI 実行時間を極端に悪化させていないか
- [ ] generator / scaffold で生成される構造から逸脱していないか
- [ ] schema 駆動 codegen の出力に手動パッチを当てる前提になっていないか
- [ ] ローカル開発手順 / onboarding に新しい暗黙手順を増やしていないか

### 10.7 歴史的背景と過去知見

- [ ] 類似 PR の設計議論や revert 履歴を確認したか
- [ ] 類似障害の postmortem で禁止されたパターンを再導入していないか
- [ ] 既存 ADR / design doc と矛盾する判断をしていないか
- [ ] 過去に「採用見送り」となったアプローチを歴史的背景なしに再提案していないか
- [ ] Deprecated な旧アーキテクチャ・社内パターンを誤って参考にしていないか
- [ ] 進行中の大規模マイグレーションを妨げたり、レガシー側に新依存を増やしていないか
- [ ] 「ボーイスカウトルール」: 旧コード削除・隔離計画がスコープに入っているか

### 10.8 UI・UX 実装規約

- [ ] 既存 UI component / design token / form pattern を再利用しているか
- [ ] アクセシビリティ pattern や keyboard interaction と整合しているか
- [ ] 既存デザインシステム / 共通パーツで代替・拡張できないか検討したか

### 10.9 依存関係・通信手段の選定

- [ ] 同等機能の別ライブラリを新規導入していないか（既存 HTTP クライアント等）
- [ ] 新規 dependency が既存方針・bundle size 方針と合っているか
- [ ] コンポーネント間通信手段（gRPC / REST / event）がチーム標準スタックから逸脱していないか
- [ ] 共有モジュールのバージョンアップが他依存と競合しないか

## design.md に必ず含めるセクション

上記チェックの結果として、以下を `design.md` に必ず含める:

- **Non-functional requirements (NFR)**: 上記 2 の数値目標
- **Security**: 上記 3 の方針
- **Observability**: 上記 5 の計測点
- **Operations / Rollout / Rollback / Migration**: 上記 4 の手順
- **Failure modes**: 上記 1 の主要シナリオと挙動
- **Blast radius**: 上記 6 の影響範囲
- **Codebase coherence**: 上記 10 の調査結果。最低限以下を明記
  - **既存類似実装の有無と差分の根拠**（重複を許容する場合はその理由）
  - **再利用する既存モジュール / helper / fixture / pattern の一覧**
  - **共有契約（公開 API / DB schema / 共通型 / shared lib）への破壊的影響と互換戦略**
  - **逸脱する既存規約があればその場所と逸脱理由**
- **Risks & Mitigations**: 上記 1-10 で抽出されたリスクと緩和策
- **Rejected alternatives**: 上記 8 の代替案と不採用理由
- **Open questions**: Phase 1-4 のレビューや実装中に検証が必要な未確定事項
