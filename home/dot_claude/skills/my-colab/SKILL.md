---
name: my-colab
description: >-
  公式の `colab` CLI で Google Colab の GPU を確保し、Python やノートブックの実行、
  学習の監視、ファイル転送、Drive マウント、ランタイム停止を行う。
  「Colab で回して」「GPU で学習して（Colab）」「colab」など、Colab が指定された依頼で使う。
  ローカル GPU や他のクラウド GPU の作業には使わない。
compatibility: Requires the official google-colab-cli on macOS or Linux, network access, and a Google account with access to the requested Colab runtime.
---

# Google Colab GPU

## 実行前

1. ジョブの入力、回収する成果物、GPU 要件を確認する。データの置き場所と容量を見積もり、
   取得元とチェックポイントの保存先を決めてからランタイムを確保する。
   [データ転送と保存](references/data-transfer.md) を参照する。
   `colab` が PATH 上になければ `"$HOME/.local/bin/colab"` を確認する。
   コマンド例は v0.7.4 の `colab --help` と `colab <command> --help` に準拠する。
2. `colab sessions` でサインインと既存ランタイムを確認する。`colab usage` の
   `Current balance` が残りのコンピューティングユニット、`Usage rate` がアカウント全体の毎時消費量。
   認証が必要なら [サインイン](#サインイン) へ進む。
3. ユーザーが指定した GPU を優先する。指定がなければ、単純な CUDA 確認や小規模な学習には
   `T4`、BF16 や T4 より多い VRAM が必要なら `L4` を選ぶ。大きなモデルやバッチで
   VRAM が必要なら `A100`、Hopper 向けの機能や対応カーネルの速度が必要なら `H100` を検討する。
   CLI は `G4` も受け付ける。GPU の空き、契約、残高によって割り当ては変わる。
   `--high-mem` は VM のシステム RAM を増やすオプション。VRAM は実機の `nvidia-smi` で確認する。
   割り当てが拒否されたらエラーを報告し、GPU 指定や利用枠の条件が変わる場合はユーザーに確認する。

### 選べるアクセラレータと消費量を調べる

- `colab new --help` で CLI が受け付ける種類を確認する。v0.7.4 は GPU が
  `T4`・`L4`・`G4`・`A100`・`H100`、TPU が `v5e1`・`v6e1`。
  この版には、アカウントごとの割り当て候補や機種別の消費レートを、確保前に一覧取得するコマンドがない。
- 候補は利用枠のあるアカウントで Colab のノートブックを開き、
  「ランタイム」→「ランタイムのタイプを変更」のハードウェア アクセラレータ欄で確認する。
  空き状況は変動するため、実際に使えるかは必要な機種を `colab new` で確保して確認する。
- 稼働時の目安は `colab usage` で測る。開始前と対象ランタイムの稼働中に実行し、
  `Active assignments` と `Usage rate` を確認する。対象1台だけが稼働中なら、表示された毎時レートを
  その実行条件での目安にできる。複数台が稼働している場合はアカウント合計なので、
  個々の GPU のレートには使わない。確認のためだけに複数の機種を順に確保しない。

## ランタイムの確保と実行

作業ごとに重複しない名前を選び、以降は毎回同じ `-s` を付ける。
**確保したランタイムは、成果物の回収後に必ず停止する。失敗・中断時も停止して確認する。**
複数のシェル呼び出しにまたがる場合は、名前を控えて最後の呼び出しまで引き継ぐ。

```bash
session="train-$(date +%Y%m%d-%H%M%S)-$$"
colab new -s "$session" --gpu T4 &&
colab status -s "$session" &&
colab exec -s "$session" <<'PY'
import subprocess

print(subprocess.check_output(["nvidia-smi"], text=True), end="")
PY
```

確保の結果が不明なら `colab sessions` で確認し、今回の操作で作成したと確認できたランタイムを扱う。

- 小さい入力ファイルは `colab upload -s "$session" ./data.csv /content/data.csv` で転送する。
  大きいデータは Drive からコピーするか、GCS・Kaggle・HF Hub などから VM 上で取得する。
  多数の小さいファイルはアーカイブで転送し、照合後に `/content` に展開する。
  依存パッケージが必要なら `colab install -s "$session" -r requirements.txt` を使う。
- 短い Python は `colab exec -s "$session" --timeout 120 -f train.py`。ローカルのスクリプトを
  読み込んで実行する。通常の Python プロセスとして引数を渡したい場合は、ファイルをアップロードし、
  `colab exec` の stdin から `subprocess.run` で起動するか、次のバックグラウンド手順を使う。
- ノートブックは `colab exec -s "$session" --timeout 300 -f analysis.ipynb`。
  CLI は入力の隣に `analysis_output.ipynb` を書き、同名のファイルがあれば上書きする。
  出力先が空いていることを確認し、既存の出力を残す場合は入力を別のディレクトリへコピーして実行する。
  実行後は出力セルのエラーと必要な成果物を確認する。
- 長時間の学習には [バックグラウンド実行](references/background-training.md) を使う。
  短い `exec` で起動した後に、別の `exec` でログ・終了コード・GPU 使用状況を確認する。
  長時間ジョブは途中経過を報告し、完了または指定された停止条件まで見届ける。
- 標準出力だけで足りる単発の Python は `colab run -s "$session" --gpu T4 --timeout 120 smoke.py`。
  スクリプトパスより後ろはスクリプトへの引数。`run` は新規 VM を使って終了時に解放する。
  終了後に `colab sessions` で解放を確認し、残っていれば停止する。

## Drive、成果物の回収、停止

- Drive が必要なときは、ユーザーが自分の端末で
  `colab drivemount -s "実際のセッション名" /content/drive` を実行し、表示された Google の認可手順を完了する。
  必要なパスを `colab ls -s "$session" /content/drive/MyDrive` で確認する。
  対話認可を待っている間は GPU の利用枠を消費し得るため、ユーザーが操作できることを確かめてから確保する。
- `colab ls -s "$session" /content` で成果物を確認し、例えば
  `colab download -s "$session" /content/result.json ./result.json` で回収する。
  ダウンロード先が既存ファイルと衝突しないことと、回収したファイルを読めることを確認する。
  VM 上のファイルは停止すると失われる。
- `colab stop -s "$session"` を実行し、`colab sessions` のサーバー側一覧から対象が消えたことを確認する。
  他のランタイムが動いていても、停止するのは今回確保したものだけ。
  停止の確認自体が失敗した場合は再確認し、確認できなければセッション名とエラーを報告する。

完了時は GPU 名、ジョブ結果、ローカルの成果物パス、ランタイムの停止確認を報告する。

## サインイン

標準の OAuth 認可を求められたら、ユーザーに自分の端末で `colab sessions` を実行してもらう。
CLI が表示する URL を開き、Colab の利用枠がある Google アカウントで同意し、
表示された認可コードを端末のプロンプトへ入力する。認可コードはチャットに貼らない。
インストール済み CLI が OAuth クライアント設定を要求する場合は、用意済みのファイルを
`colab --client-oauth-config /path/to/client.json sessions` で指定するか、ADC を使う。
設定ファイルを指定した場合は、停止と確認を含む後続のコマンドにも同じグローバルオプションを付ける。

ADC を使う場合は、ユーザーの端末で次を実行する。

```bash
gcloud auth application-default login \
  --scopes=openid,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/colaboratory
colab --auth=adc sessions
```

ADC で続ける場合は、停止と確認を含むすべてのコマンドで `--auth=adc` をサブコマンドの前に置く。
ユーザー操作が必要な場合は、必要なコマンドを伝え、サインインの完了後に確保へ進む。

参照先は [公式 Colab CLI](https://github.com/googlecolab/google-colab-cli) と
[Colab の利用制限と GPU](https://research.google.com/colaboratory/faq.html)。
