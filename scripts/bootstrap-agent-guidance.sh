#!/usr/bin/env bash

set -euo pipefail

ORG="PrivChain"
DRY_RUN=true
INCLUDE_PUBLIC=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: bootstrap-agent-guidance.sh [options]

Options:
  -o, --org <name>      GitHub organization (default: PrivChain)
      --apply           Apply changes (default is dry-run)
      --include-public  Also update public repositories
  -h, --help            Show this help message

Behavior:
  - Updates AGENTS.md and CLAUDE.md in each target repository.
  - Updates agent-guidance/PRINCIPLES.md and agent-guidance/HEURISTICS.md.
  - By default, targets private repositories only.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--org)
      ORG="${2:-}"
      shift 2
      ;;
    --apply)
      DRY_RUN=false
      shift
      ;;
    --include-public)
      INCLUDE_PUBLIC=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI is required." >&2
  exit 1
fi

if [[ -z "$ORG" ]]; then
  echo "Error: organization name is required." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

for required in \
  "$REPO_ROOT/AGENTS.md" \
  "$REPO_ROOT/CLAUDE.md" \
  "$REPO_ROOT/agent-guidance/PRINCIPLES.md" \
  "$REPO_ROOT/agent-guidance/HEURISTICS.md"; do
  if [[ ! -f "$required" ]]; then
    echo "Error: required source file missing: $required" >&2
    exit 1
  fi
done

put_file() {
  local repo="$1"
  local branch="$2"
  local target_path="$3"
  local source_file="$4"

  local content sha b64
  content="$(cat "$source_file")"
  b64="$(printf '%s' "$content" | base64 | tr -d '\n')"
  sha="$(gh api "/repos/$ORG/$repo/contents/$target_path?ref=$branch" --jq '.sha' 2>/dev/null || true)"

  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY   $repo:$target_path"
    return 0
  fi

  if [[ -n "$sha" ]]; then
    gh api --method PUT "/repos/$ORG/$repo/contents/$target_path" \
      -f message="chore: bootstrap agent guidance baseline" \
      -f content="$b64" \
      -f branch="$branch" \
      -f sha="$sha" >/dev/null
  else
    gh api --method PUT "/repos/$ORG/$repo/contents/$target_path" \
      -f message="chore: bootstrap agent guidance baseline" \
      -f content="$b64" \
      -f branch="$branch" >/dev/null
  fi

  echo "DONE  $repo:$target_path"
}

echo "Org: $ORG"
echo "Mode: $([[ "$DRY_RUN" == true ]] && echo "dry-run" || echo "apply")"
echo "Include public repos: $INCLUDE_PUBLIC"
echo

repos="$(
  gh api --paginate "/orgs/$ORG/repos?type=all&per_page=100" \
    --jq '.[] | select(.archived | not) | [.name, .visibility, .default_branch] | @tsv'
)"

if [[ -z "$repos" ]]; then
  echo "No repositories found for org: $ORG"
  exit 0
fi

scanned=0
touched=0
skipped=0
errors=0

while IFS=$'\t' read -r repo visibility default_branch; do
  [[ -z "${repo:-}" ]] && continue
  scanned=$((scanned + 1))

  if [[ -z "${default_branch:-}" || "$default_branch" == "null" ]]; then
    echo "SKIP  $repo (no default branch)"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$visibility" == "public" && "$INCLUDE_PUBLIC" != true ]]; then
    echo "SKIP  $repo (public repo; use --include-public to include)"
    skipped=$((skipped + 1))
    continue
  fi

  echo "REPO  $repo [$visibility] branch=$default_branch"

  if put_file "$repo" "$default_branch" "AGENTS.md" "$REPO_ROOT/AGENTS.md" &&
     put_file "$repo" "$default_branch" "CLAUDE.md" "$REPO_ROOT/CLAUDE.md" &&
     put_file "$repo" "$default_branch" "agent-guidance/PRINCIPLES.md" "$REPO_ROOT/agent-guidance/PRINCIPLES.md" &&
     put_file "$repo" "$default_branch" "agent-guidance/HEURISTICS.md" "$REPO_ROOT/agent-guidance/HEURISTICS.md"; then
    touched=$((touched + 1))
  else
    echo "ERROR $repo (failed to update one or more files)"
    errors=$((errors + 1))
  fi
done <<< "$repos"

echo
echo "Summary"
echo "  Repositories scanned: $scanned"
echo "  Repositories updated: $touched"
echo "  Repositories skipped: $skipped"
echo "  Repositories failed:  $errors"

if [[ "$errors" -gt 0 ]]; then
  exit 1
fi
