#!/usr/bin/env bash

set -uo pipefail

ORG="PrivChain"
PAYLOAD_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/branch-protection-main.json"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: apply-main-branch-protection.sh [options]

Options:
  -o, --org <name>        GitHub organization (default: PrivChain)
  -p, --payload <path>    Branch protection JSON payload file
  -n, --dry-run           Print actions without applying changes
  -h, --help              Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--org)
      ORG="${2:-}"
      shift 2
      ;;
    -p|--payload)
      PAYLOAD_FILE="${2:-}"
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=true
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

if [[ ! -f "$PAYLOAD_FILE" ]]; then
  echo "Error: payload file not found: $PAYLOAD_FILE" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

echo "Org: $ORG"
echo "Payload: $PAYLOAD_FILE"
echo "Mode: $([[ "$DRY_RUN" == true ]] && echo "dry-run" || echo "apply")"
echo

repo_lines="$(
  gh api --paginate \
    "/orgs/$ORG/repos?type=all&per_page=100" \
    --jq '.[] | [.name, .visibility, .default_branch] | @tsv'
)"

if [[ -z "$repo_lines" ]]; then
  echo "No repositories found for org: $ORG"
  exit 0
fi

total=0
applied=0
skipped=0
errors=0
skipped_details=()
error_details=()

while IFS=$'\t' read -r repo visibility default_branch; do
  [[ -z "${repo:-}" ]] && continue
  total=$((total + 1))

  if [[ -z "${default_branch:-}" || "${default_branch:-null}" == "null" ]]; then
    echo "SKIP  $repo (no default branch)"
    skipped=$((skipped + 1))
    skipped_details+=("$repo: no default branch")
    continue
  fi

  echo "APPLY $repo [$visibility] branch=$default_branch"

  if [[ "$DRY_RUN" == true ]]; then
    applied=$((applied + 1))
    continue
  fi

  if output="$(
    gh api --method PUT \
      "/repos/$ORG/$repo/branches/$default_branch/protection" \
      --input "$PAYLOAD_FILE" 2>&1
  )"; then
    applied=$((applied + 1))
    continue
  fi

  if grep -q "Upgrade to GitHub Pro or make this repository public" <<<"$output"; then
    echo "SKIP  $repo (plan-gated for private repository)"
    skipped=$((skipped + 1))
    skipped_details+=("$repo: plan-gated private repo")
    continue
  fi

  echo "ERROR $repo"
  errors=$((errors + 1))
  error_details+=("$repo: $(echo "$output" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')")
done <<< "$repo_lines"

echo
echo "Summary"
echo "  Repositories scanned: $total"
echo "  Applied: $applied"
echo "  Skipped: $skipped"
echo "  Errors: $errors"

if [[ ${#skipped_details[@]} -gt 0 ]]; then
  echo
  echo "Skipped details:"
  printf '  - %s\n' "${skipped_details[@]}"
fi

if [[ ${#error_details[@]} -gt 0 ]]; then
  echo
  echo "Error details:"
  printf '  - %s\n' "${error_details[@]}"
  exit 1
fi
