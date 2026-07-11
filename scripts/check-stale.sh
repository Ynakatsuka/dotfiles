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
#   7. preferred agent CLI tools missing from mise management
#   8. rules/*.md files not mentioned in repository instructions
#   9. oversized, duplicated, or conflicting global agent instruction sources
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
ALLOWED_TOP_LEVEL=".chezmoiroot .github .gitignore .pre-commit-config.yaml AGENTS.md CLAUDE.md README.md bootstrap home scripts"
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
  [ -f "${tmpl}" ] || continue
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
  # Docs reference DEPLOYED names; chezmoi source names may carry attribute
  # prefixes (executable_, private_), so check the prefixed variants too.
  # my-skill-creator is exempt: its guide is full of illustrative example
  # paths (scripts/fetch_data.py, references/aws.md, ...) that are not files.
  if [ "$(basename "${skill_dir}")" != "my-skill-creator" ]; then
    while IFS= read -r mention; do
      mention_dir="$(dirname "${mention}")"
      mention_base="$(basename "${mention}")"
      if [ ! -e "${skill_dir}/${mention}" ] &&
        [ ! -e "${skill_dir}/${mention_dir}/executable_${mention_base}" ] &&
        [ ! -e "${skill_dir}/${mention_dir}/private_${mention_base}" ]; then
        fail "${skill_dir}: docs mention missing file: ${mention}"
      fi
    done < <(grep -RhoE '(scripts|references)/[A-Za-z0-9._/-]+\.[A-Za-z0-9]+' \
      --include='*.md' "${skill_dir}" | sort -u)
  fi

  # 5b. every script/reference file must be reachable from the skill's docs.
  # Strip chezmoi attribute prefixes so a source file named
  # executable_foo.sh matches docs that reference the deployed foo.sh.
  while IFS= read -r file; do
    base="$(basename "${file}")"
    base="${base#executable_}"
    base="${base#private_}"
    case "${base}" in
      LICENSE.txt) continue ;;
    esac
    grep -Rq --include='*.md' -F "${base}" "${skill_dir}" ||
      fail "${skill_dir}: orphan file never referenced from any .md: ${file#"${skill_dir}"/}"
  done < <(find "${skill_dir}/scripts" "${skill_dir}/references" -type f 2>/dev/null)
done

# --- 6. Makefile target drift ---------------------------------------------------
makefile_targets="$(grep -oE '^[a-z][a-z-]*:' bootstrap/Makefile | tr -d ':')"
for doc in README.md AGENTS.md CLAUDE.md bootstrap/README.md; do
  while IFS= read -r target; do
    grep -qx "${target}" <<<"${makefile_targets}" ||
      fail "${doc}: mentions non-existent Makefile target: make -C bootstrap ${target}"
  done < <(grep -oE 'make -C [^ ]*bootstrap"? [a-z][a-z-]*' "${doc}" | awk '{print $NF}' | sort -u)
done

# --- 7. Agent tool expectations vs mise ------------------------------------------
# Agent instructions prefer these CLIs when available; keep them mise-managed.
for pair in rg:ripgrep fd:fd ast-grep:ast-grep jq:jq yq:yq; do
  mise_name="${pair#*:}"
  grep -qE "^\"?${mise_name}\"? = " home/private_dot_config/mise/config.toml ||
    fail "AGENTS.md relies on '${pair%%:*}' but '${mise_name}' is not in home/private_dot_config/mise/config.toml"
done

# --- 8. rules/*.md drift against repository instructions --------------------------
for rule in home/dot_claude/rules/*.md; do
  base="$(basename "${rule}" .md)"
  grep -q "${base}" AGENTS.md ||
    fail "AGENTS.md does not mention rules/${base}.md"
done

# --- 9. Agent instruction integrity ---------------------------------------------
agents_lines="$(wc -l <home/AGENTS.md)"
agents_bytes="$(wc -c <home/AGENTS.md)"
[ "${agents_lines}" -le 200 ] || fail "home/AGENTS.md exceeds 200 lines: ${agents_lines}"
[ "${agents_bytes}" -le 32768 ] || fail "home/AGENTS.md exceeds 32 KiB: ${agents_bytes} bytes"

for template in \
  home/dot_claude/CLAUDE.md.tmpl \
  home/dot_codex/AGENTS.md.tmpl \
  home/dot_gemini/GEMINI.md.tmpl; do
  include_count="$(grep -c 'include "AGENTS.md"' "${template}" || true)"
  [ "${include_count}" -eq 1 ] || fail "${template}: expected exactly one AGENTS.md include, found ${include_count}"
done

[ ! -e home/CLAUDE.md.tmpl ] || fail "home/CLAUDE.md.tmpl duplicates ~/.claude/CLAUDE.md for repositories under HOME"
grep -qx 'CLAUDE.md' home/.chezmoiremove || fail "home/.chezmoiremove must remove the former ~/CLAUDE.md target"
grep -q '^@AGENTS\.md$' CLAUDE.md || fail "CLAUDE.md must import the repository AGENTS.md"

if grep -Eqi 'chezmoi|dotfiles|Ynakatsuka/dotfiles|ghq/github.com/Ynakatsuka/dotfiles' home/AGENTS.md; then
  fail "home/AGENTS.md contains repository-specific dotfiles guidance"
fi

# --- Summary ----------------------------------------------------------------------
if [ "${FAILURES}" -gt 0 ]; then
  echo "check-stale: ${FAILURES} problem(s) found" >&2
  exit 1
fi
echo "check-stale: OK"
