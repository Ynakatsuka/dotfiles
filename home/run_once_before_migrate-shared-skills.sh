#!/usr/bin/env bash
# Move the formerly agent-owned skills to the common Claude source directory.

set -euo pipefail

agent_skills="${HOME}/.agents/skills"
claude_skills="${HOME}/.claude/skills"
skills=(my-bulk-read my-code-write my-subagent orca-cli)

for skill in "${skills[@]}"; do
  agent_skill="${agent_skills}/${skill}"
  claude_skill="${claude_skills}/${skill}"
  [[ -d "${agent_skill}" && ! -L "${agent_skill}" ]] || continue

  if [[ -e "${claude_skill}" || -L "${claude_skill}" ]]; then
    if [[ ! -L "${claude_skill}" || "$(readlink "${claude_skill}")" != "../../.agents/skills/${skill}" ]]; then
      echo "ERROR: Cannot migrate ${skill}: unexpected Claude skill at ${claude_skill}" >&2
      exit 1
    fi
  fi
done

mkdir -p "${claude_skills}"
for skill in "${skills[@]}"; do
  agent_skill="${agent_skills}/${skill}"
  claude_skill="${claude_skills}/${skill}"
  [[ -d "${agent_skill}" && ! -L "${agent_skill}" ]] || continue

  if [[ -L "${claude_skill}" ]]; then
    rm "${claude_skill}"
  fi
  mv "${agent_skill}" "${claude_skill}"
  echo "Moved ${skill} to ${claude_skill}"
done
