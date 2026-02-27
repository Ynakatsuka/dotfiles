---
paths: "**/*.py"
---

When applying this rule, prefix your response with the 🧩 emoji.

## GPU Usage

### Running Scripts with GPU

- When running scripts that use **torch**, they typically require GPU access.
- **Always specify the `CUDA_VISIBLE_DEVICES` environment variable** when executing such scripts.
- Example: To use GPU 0, run:

  ```bash
  CUDA_VISIBLE_DEVICES=0 uv run main.py
  ```

### Selecting Available GPUs

- Before running a GPU-intensive script, use `nvidia-smi` to check which GPUs are currently available and not in use.
- Select an unused GPU and set `CUDA_VISIBLE_DEVICES` accordingly to avoid conflicts with other processes.
