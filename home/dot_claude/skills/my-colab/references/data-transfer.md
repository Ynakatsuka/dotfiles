# Colab へのデータ転送と保存

## 転送方法と容量を決める

| データの状況 | 転送方法 |
| --- | --- |
| 小さいファイルが数個 | 手元から `colab upload -s "$session" ./data.csv /content/data.csv` で送る。 |
| 小さいファイルが多数 | tar または zip でまとめて送る。アーカイブが大きければ Drive やオブジェクトストレージに置き、VM から取得する。 |
| 大きいデータが Drive にある | `colab drivemount -s "$session" /content/drive` でマウントし、アーカイブを `/content` にコピーして展開する。 |
| 大きいデータが GCS・Kaggle・HF Hub にある | VM から取得元に直接接続し、`/content` に保存する。手元を経由する転送を省ける。 |

大きなデータが分割されていれば、シャード単位で取得・処理し、同時に展開する量を抑える。
Drive 上の多数の小さいファイルを学習ループから直接開くと I/O が詰まりやすい。
ローカルディスク上に展開してから読む。[Colab の Drive I/O に関する FAQ](https://research.google.com/colaboratory/faq.html)

- 確保前に、手元の入力なら `du -sh ./dataset`、公開元なら配布メタデータやファイル一覧でサイズを見積もる。
  転送・展開前に VM 上で `df -h /content` を確認する。空き容量には、アーカイブ、展開後のデータ、
  ダウンロードの一時ファイルやキャッシュ、チェックポイントの書き出し領域を見込む。
  ファイル数が多い場合は `df -i /content` で空き inode も確認する。
- `colab upload` は v0.7.4 ではファイル全体を読み込んで Base64 化する。
  途中再開用オプションがないため、小さいファイルや小さめのアーカイブに使う。
  大きいデータは再開できる取得元か独立したシャードを選ぶ。

## アーカイブを送り、照合して展開する

転送するファイルだけを `dataset/` に置く。手元で tar と SHA-256 の照合ファイルを作る。
ランタイム名を `session` に設定してから実行する。`shasum` は手元、`sha256sum` は VM 上で使う。

```bash
tar -czf dataset.tar.gz dataset &&
shasum -a 256 dataset.tar.gz > dataset.tar.gz.sha256 &&
colab upload -s "$session" ./dataset.tar.gz /content/dataset.tar.gz &&
colab upload -s "$session" ./dataset.tar.gz.sha256 /content/dataset.tar.gz.sha256 &&
colab exec -s "$session" --timeout 120 <<'PY'
from pathlib import Path
import subprocess

def checked(*args):
    result = subprocess.run(
        args, cwd="/content", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    )
    print(result.stdout, end="")
    result.check_returncode()

checked("sha256sum", "--check", "dataset.tar.gz.sha256")
output = Path("/content/my-colab-data")
output.mkdir()
checked("tar", "-xzf", "dataset.tar.gz", "-C", str(output))
print(f"DATASET_READY: {output / 'dataset'}")
PY
```

`dataset.tar.gz: OK` と `DATASET_READY` を確認してから `/content/my-colab-data/dataset` を使う。
照合に失敗したファイルは取り直す。外部のアーカイブは、配布元が提示するチェックサムと照合する。
信頼できる入力を、空のディレクトリに展開する。展開に失敗したら原因を確認し、再試行は空の別ディレクトリで行う。

## 大きいデータを VM から取得する

以下のコマンドは VM 側で実行する。`colab exec` から起動するときは
`subprocess.run([...], check=True)` で結果を確認し、サイズに応じてタイムアウトを設定する。
時間がかかる転送は [バックグラウンド実行](background-training.md) と同じようにログと終了コードを残す。

- **Drive** はマウント済みの `/content/drive/MyDrive` から `cp` でアーカイブを `/content` にコピーする。
  照合が済むまでコピー元を保持する。大きな一式を繰り返し取得するならシャードごとに
  SHA-256 を記録し、未完了の分だけ再取得する。
- **GCS** は VM で `command -v gcloud` を確認する。非公開バケットでは、ユーザーの端末から
  `colab auth -s "$session"` で VM の Google 認証を済ませる。このコマンドのヘルプは
  `colab help auth` で確認できる。必要なバケットの権限を持つアカウントで
  `gcloud storage cp gs://BUCKET/path/dataset.tar.gz /content/dataset.tar.gz` を実行する。
  同じ VM でダウンロードが中断したら、途中ファイルを残して同じ `cp` コマンドを再実行する。
  [認証](https://cloud.google.com/storage/docs/authentication) ·
  [GCS ダウンロードと再開](https://cloud.google.com/storage/docs/downloading-objects)
- **Kaggle** は必要に応じて `colab install -s "$session" kaggle` で CLI を用意し、
  VM 上で `kaggle datasets download OWNER/DATASET -p /content`
  でアーカイブを取得する。認証が必要なら下記の方法を使う。複数ファイルを個別に取れるデータセットは
  `-f FILE` で対象を指定できる。[Kaggle CLI のデータセット操作](https://github.com/Kaggle/kaggle-cli/blob/main/docs/datasets.md)
- **HF Hub** は必要に応じて `colab install -s "$session" huggingface_hub` で CLI を用意し、
  VM 上で `hf download OWNER/DATASET --repo-type dataset --revision COMMIT --local-dir /content/hf-data`
  で版を固定して取得する。同じ `--local-dir` とキャッシュを残して再実行すると、
  取得済みのファイルを再利用できる。[HF CLI の取得手順](https://huggingface.co/docs/huggingface_hub/guides/cli)
- **HTTP(S)** で配布元が Range リクエストをサポートするなら、バージョン固定の URL を
  `curl --fail --location --continue-at - --output /content/dataset.tar.gz.part URL`
  で取得し、中断時は同じコマンドで再開する。期待した SHA-256 と一致してから `.part` を外す。
  Range 非対応なら、配布元のツールかシャード単位の取得を使う。[curl の再開オプション](https://curl.se/docs/manpage.html#-C)

## 秘密情報を渡す

秘密が必要な場合は、ユーザーが `colab url -s "$session"` で表示した URL を開き、
同じ VM に接続したノートブックの「シークレット」に `KAGGLE_API_TOKEN` または
`HF_TOKEN` を登録し、そのノートブックへのアクセスを許可する。
`google.colab.userdata.get` は Colab の画面から実行するセルで使う。
例ではシークレットを Kaggle の子プロセスにだけ渡し、VM 上の `/content` に取得する。

```python
import os
import subprocess
from google.colab import userdata

subprocess.run(
    ["kaggle", "datasets", "download", "OWNER/DATASET", "-p", "/content"],
    env={**os.environ, "KAGGLE_API_TOKEN": userdata.get("KAGGLE_API_TOKEN")},
    check=True,
)
```

HF Hub も同じ方法で `HF_TOKEN` を `hf download` の環境に渡せる。読み取り権限のトークンを使う。
トークンの値はノートブック、転送ファイル、CLI 引数、ログに入れない。
`colab exec --env` に秘密を渡すと CLI の実行履歴に残り得るため、使用しない。
[Colab の userdata 実装](https://github.com/googlecolab/colabtools/blob/main/google/colab/userdata.py) ·
[Kaggle CLI の認証](https://github.com/Kaggle/kaggle-cli/blob/main/docs/README.md#authentication) ·
[HF_TOKEN](https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables#hftoken)

## 学習中に成果物を保存する

- 数分ごと、またはエポックごとなど、失っても許容できる間隔でチェックポイントを作る。
  `/content` に一時ファイルとして書き、書き終えて閉じてから確定名へ置き換える。
  学習を再開するために必要なモデル、オプティマイザ、学習ステップなどを含める。
- チェックポイントや中間成果物は、作成後すぐ Drive または GCS のジョブ別パスへコピーする。
  Drive では一時名にコピーし、サイズと SHA-256 を照合してから確定名に変更する。
  GCS では `gcloud storage cp /content/checkpoints/step-1000.pt gs://BUCKET/runs/RUN_ID/step-1000.pt`
  のようにステップごとに別の名前で保存する。アップロードが中断した場合、同じ VM なら
  一時状態を残して同じコマンドで再開できる。[GCS の再開可能なアップロード](https://cloud.google.com/storage/docs/resumable-uploads)
- 永続側でコピー完了を確認し、最後に正常保存されたチェックポイントとログの場所を控える。
  VM を取り直したら、その保存先から照合済みのチェックポイントをローカルディスクへ取得して再開する。
