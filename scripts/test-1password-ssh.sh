#!/usr/bin/env bash
# Verify effective SSH settings for both supported OSes, with and without the app.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
python3 - "$repo_root" <<'PY'
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(sys.argv[1])
template = (repo / "home/private_dot_ssh/config.d/1password.conf.tmpl").read_text()
with tempfile.TemporaryDirectory(prefix="test-1password-ssh.") as directory:
    fixture = Path(directory)
    config = fixture / "chezmoi.toml"
    config.touch()
    signer = fixture / "op-ssh-sign"
    for system in ("darwin", "linux"):
        for installed in (False, True):
            if installed:
                signer.touch()
            else:
                signer.unlink(missing_ok=True)
            # Redirect only the app installation paths; retain the actual stat guard.
            source = template.replace(
                "/Applications/1Password.app/Contents/MacOS/op-ssh-sign", str(signer)
            ).replace("/opt/1Password/op-ssh-sign", str(signer))
            source = '{{ with dict "chezmoi" (dict "os" "' + system + '") }}' + source + "{{ end }}"
            rendered = subprocess.run(
                ["chezmoi", "--config", str(config), "execute-template"],
                input=source, text=True, capture_output=True, check=True,
            ).stdout
            if not installed:
                assert not rendered.strip(), (system, rendered)
            ssh_config = fixture / "ssh.conf"
            ssh_config.write_text(rendered)
            for host in ("github.com", "example.com"):
                output = subprocess.run(
                    ["ssh", "-G", "-T", "-F", str(ssh_config), host],
                    text=True, capture_output=True, check=True,
                ).stdout
                effective = dict(line.split(" ", 1) for line in output.splitlines())
                selected = installed and host == "github.com"
                assert effective["identitiesonly"] == ("yes" if selected else "no")
                if selected:
                    suffix = "com.1password/t/agent.sock" if system == "darwin" else ".1password/agent.sock"
                    assert effective["identityagent"].endswith(suffix), effective
                    assert "1password-github.pub" in effective["identityfile"], effective
                else:
                    assert effective.get("identityagent", "none") == "none", effective
print("test-1password-ssh: OK")
PY
