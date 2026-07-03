#!/usr/bin/env bash
# Stale-content detector for this dotfiles repo.
#
# Detects structural staleness that otherwise rots silently:
#   1. unexpected top-level entries (deployable files belong under home/)
#   2. junk in the chezmoi source that would deploy to $HOME
#   3. empty directories under home/ (chezmoi cannot deploy them)
#   4. template include/includeTemplate targets that no longer exist
#   5. skill files referenced in docs but missing, and orphan skill files
#   6. Makefile targets mentioned in docs that do not exist
#   7. CLI tools mandated by AGENTS.md missing from mise management
#   8. rules/*.md files not mentioned in CLAUDE.md
#
# Detection only: nothing is deleted here. Stale deployed files are removed
# declaratively via home/.chezmoiremove on `chezmoi apply`.
#
# Run directly or via pre-commit / CI. Exits non-zero when anything is stale.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FAILURES=0
fail() {
  echo "FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

# --- 1. Top-level layout -----------------------------------------------------
# .chezmoiroot narrows the chezmoi source to home/; anything else at the top
# level is repo-only. New entries must be added here deliberately.
ALLOWED_TOP_LEVEL=".chezmoiroot .github .gitignore .pre-commit-config.yaml CLAUDE.md README.md bootstrap home scripts"
while IFS= read -r entry; do
  case " ${ALLOWED_TOP_LEVEL} " in
    *" ${entry} "*) ;;
    *) fail "unexpected top-level entry: ${entry} (deployable files belong under home/; deliberate repo-only entries go into ALLOWED_TOP_LEVEL in scripts/check-stale.sh)" ;;
  esac
done < <(git ls-files | cut -d/ -f1 | sort -u)

# --- 2. Junk that would deploy ----------------------------------------------
# chezmoi reads the working tree, so even untracked junk under home/ deploys.
while IFS= read -r junk; do
  fail "junk in chezmoi source (would deploy to \$HOME): ${junk}"
done < <(find home \( -name '__pycache__' -o -name '*.pyc' -o -name '.DS_Store' \) -print)

# --- 3. Empty directories under home/ ----------------------------------------
while IFS= read -r dir; do
  fail "empty directory in chezmoi source (chezmoi cannot deploy it): ${dir}"
done < <(find home -type d -empty -print)

# --- 4. Template include targets ----------------------------------------------
# include paths resolve relative to home/, includeTemplate relative to
# home/.chezmoitemplates/.
while IFS= read -r tmpl; do
  while IFS= read -r target; do
    [ -e "home/${target}" ] || fail "${tmpl}: include target missing: home/${target}"
  done < <(grep -oE 'include "[^"]+"' "${tmpl}" | sed -e 's/^include "//' -e 's/"$//')
  while IFS= read -r target; do
    [ -e "home/.chezmoitemplates/${target}" ] || fail "${tmpl}: includeTemplate target missing: home/.chezmoitemplates/${target}"
  done < <(grep -oE 'includeTemplate "[^"]+"' "${tmpl}" | sed -e 's/^includeTemplate "//' -e 's/"$//')
done < <(
  git ls-files home | grep -E '\.tmpl$'
  git ls-files home/.chezmoiignore home/.chezmoiremove
)

# --- 5. Skill integrity --------------------------------------------------------
for skill_md in home/dot_claude/skills/*/SKILL.md; do
  skill_dir="$(dirname "${skill_md}")"

  # 5a. paths mentioned in the skill's markdown must exist.
  # my-skill-creator is exempt: its guide is full of illustrative example
  # paths (scripts/fetch_data.py, references/aws.md, ...) that are not files.
  if [ "$(basename "${skill_dir}")" != "my-skill-creator" ]; then
    while IFS= read -r mention; do
      [ -e "${skill_dir}/${mention}" ] || fail "${skill_dir}: docs mention missing file: ${mention}"
    done < <(grep -RhoE '(scripts|references)/[A-Za-z0-9._/-]+\.[A-Za-z0-9]+' \
      --include='*.md' "${skill_dir}" | sort -u)
  fi

  # 5b. every script/reference file must be reachable from the skill's docs
  while IFS= read -r file; do
    base="$(basename "${file}")"
    case "${base}" in
      LICENSE.txt) continue ;;
    esac
    grep -Rq --include='*.md' -F "${base}" "${skill_dir}" ||
      fail "${skill_dir}: orphan file never referenced from any .md: ${file#"${skill_dir}"/}"
  done < <(find "${skill_dir}/scripts" "${skill_dir}/references" -type f 2>/dev/null)
done

# --- 6. Makefile target drift ---------------------------------------------------
makefile_targets="$(grep -oE '^[a-z][a-z-]*:' bootstrap/Makefile | tr -d ':')"
for doc in README.md CLAUDE.md bootstrap/README.md; do
  while IFS= read -r target; do
    grep -qx "${target}" <<<"${makefile_targets}" ||
      fail "${doc}: mentions non-existent Makefile target: make -C bootstrap ${target}"
  done < <(grep -oE 'make -C [^ ]*bootstrap"? [a-z][a-z-]*' "${doc}" | awk '{print $NF}' | sort -u)
done

# --- 7. AGENTS.md tool expectations vs mise -------------------------------------
# AGENTS.md instructs agents to use these CLIs; they must stay mise-managed.
for pair in rg:ripgrep fd:fd ast-grep:ast-grep jq:jq yq:yq; do
  mise_name="${pair#*:}"
  grep -qE "^\"?${mise_name}\"? = " home/dot_mise.toml ||
    fail "AGENTS.md relies on '${pair%%:*}' but '${mise_name}' is not in home/dot_mise.toml"
done

# --- 8. rules/*.md drift against CLAUDE.md ---------------------------------------
for rule in home/dot_claude/rules/*.md; do
  base="$(basename "${rule}" .md)"
  grep -q "${base}" CLAUDE.md ||
    fail "CLAUDE.md rules list does not mention rules/${base}.md"
done

# --- Summary ----------------------------------------------------------------------
if [ "${FAILURES}" -gt 0 ]; then
  echo "check-stale: ${FAILURES} problem(s) found" >&2
  exit 1
fi
echo "check-stale: OK"
