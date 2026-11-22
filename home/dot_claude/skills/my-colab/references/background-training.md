# バックグラウンドで学習する

名前付きランタイムを確保済みとする。学習スクリプトと入力をアップロードし、
プロセスを VM 上で起動する。例では `train.py` がカレントディレクトリに成果物を保存する。
引数やデータのパス、成果物名は実際のスクリプトに合わせる。

```bash
colab upload -s "$session" ./train.py /content/train.py &&
colab exec -s "$session" <<'PY'
from pathlib import Path
import subprocess
import sys

job = Path("/content/training")
job.mkdir()  # 同じディレクトリで二重起動しない。
with (job / "train.log").open("wb") as log:
    process = subprocess.Popen(
        [
            "bash", "-c",
            'rc=0; "$@" || rc=$?; '
            'printf "%s\\n" "$rc" > exit-code.tmp && mv exit-code.tmp exit-code',
            "train", sys.executable, "-u", "/content/train.py",
        ],
        cwd=job,
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
(job / "pid").write_text(str(process.pid))
print(f"Started PID {process.pid}; log: {job / 'train.log'}")
PY
```

別の呼び出しで進捗を見る。Jupyter カーネルが IDLE と表示されても子プロセスは動き得る。

```bash
colab exec -s "$session" <<'PY'
from pathlib import Path
import subprocess

job = Path("/content/training")
result = job / "exit-code"
pid_file = job / "pid"
has_pid = pid_file.exists()
process_status = ""
if has_pid:
    status = subprocess.run(
        ["ps", "-p", pid_file.read_text().strip(), "-o", "stat=,etime=,args="],
        capture_output=True, text=True, check=False,
    )
    process_status = status.stdout.strip()

# ps の実行中に学習が終わることがあるので、終了コードはその後に確認する。
if result.exists():
    print(f"Training exit code: {result.read_text().strip()}")
elif process_status and not process_status.startswith("Z"):
    print(process_status)
elif has_pid:
    print("Process missing; no exit code recorded")
else:
    print("PID missing; check whether the job started")

log = job / "train.log"
if log.exists():
    print(subprocess.check_output(["tail", "-n", "40", log], text=True, errors="replace"))
PY
```

- `exit-code` が 0 なら成果物を確認する。非ゼロ、またはプロセスが見つからず終了コードもない場合は、
  ログを回収して失敗として扱う。CLI 自体の終了コードで学習の成否を判断しない。
  GPU の実使用は `colab exec -s "$session"` の stdin から `nvidia-smi` を実行して確認する。
- PID が未記録なら、ログと VM 上のプロセスを確認する。起動していないと確認できた場合は、
  別名の作業ディレクトリを起動と監視の両方に指定してやり直す。
- ランタイムの寿命と利用枠の制限は、バックグラウンドでも適用される。
  長い学習はチェックポイントを保存し、必要に応じてローカルに回収するかマウント済みの Drive に同期する。
- 停止前に `colab download -s "$session" /content/training/train.log ./train.log` でログを回収する。
  成果物も同様に回収し、`colab stop -s "$session"` と `colab sessions` で解放を確認する。
