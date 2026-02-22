# PrivChain Repository Policies

This document tracks currently enforced GitHub policy controls and known plan-based limits.

## Enforced Now

### 1) Organization-wide community defaults (`PrivChain/.github`)

Applied defaults used by repos that do not override them:

- `SECURITY.md`
- `SUPPORT.md`
- `CODE_OF_CONDUCT.md`
- `CONTRIBUTING.md`
- `.github/pull_request_template.md`
- `.github/ISSUE_TEMPLATE/*`

### 2) Merge policy (all repositories)

Applied to all `PrivChain` repositories:

- Squash merge: enabled
- Merge commit: disabled
- Rebase merge: disabled
- Delete branch on merge: enabled

### 3) Branch protection (public repositories)

Applied on `main` for public repositories:

- `PrivChain/.github`
- `PrivChain/privchain-website`

Protection baseline:

- Pull requests required with 1 approval
- Dismiss stale approvals on new commits
- Require conversation resolution
- Enforce linear history
- Block force pushes
- Block branch deletion
- Enforce for admins

### 4) Agent guidance baseline

Canonical guidance is maintained in this repository:

- `AGENTS.md`
- `CLAUDE.md`
- `agent-guidance/PRINCIPLES.md`
- `agent-guidance/HEURISTICS.md`

For consistency across org repositories, use:

- `scripts/bootstrap-agent-guidance.sh` (dry-run by default)

Examples:

```bash
# Preview changes for private repos only
./scripts/bootstrap-agent-guidance.sh --org PrivChain

# Apply to private repos
./scripts/bootstrap-agent-guidance.sh --org PrivChain --apply

# Preview all repos (public + private)
./scripts/bootstrap-agent-guidance.sh --org PrivChain --include-public
```

Note: public repositories with enforced PR branch protection are intentionally skipped in apply mode and should be updated through a standard PR flow.

## Plan-based Limit

Private repositories cannot currently enable branch protection/rulesets on the current GitHub plan.
GitHub API returns plan-gated responses for private-repo branch protection.

## Automation

This repo includes a repeatable script to apply the branch-protection baseline to default branches:

- Script: `scripts/apply-main-branch-protection.sh`
- Payload: `scripts/branch-protection-main.json`

Dry run (no writes):

```bash
./scripts/apply-main-branch-protection.sh --org PrivChain --dry-run
```

Apply protections:

```bash
./scripts/apply-main-branch-protection.sh --org PrivChain
```

The script attempts all repositories and gracefully skips plan-gated private repositories when GitHub returns a 403 upgrade response.

## Recommended Next Step (After Plan Upgrade)

After upgrading to a plan that supports private-repo protections, apply the same `main` protection baseline to:

- `privchain-spec`
- `priv-examples`
- `priv-wallet`
- `priv-mcp`
- `priv-sdk-py`
- `priv-sdk-ts`
- `privchain-protocol`

And optionally add organization rulesets for centralized governance and auditability.

Post-upgrade command:

```bash
./scripts/apply-main-branch-protection.sh --org PrivChain
```
