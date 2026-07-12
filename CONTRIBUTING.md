# Contributing to Mnemo

Mnemo uses an **autonomous-development workflow** driven by GitHub Issues and a long-lived integration branch.

## Branches

- **`main`** — release branch. Only the repository owner merges into `main`.
- **`dev-workflow`** — long-lived integration branch. All feature/fix/refactor/chore work merges here first.
- **`feature/<issue>-slug`**, **`fix/<issue>-slug`**, **`refactor/<issue>-slug`**, **`chore/<issue>-slug`** — short-lived per-issue branches, cut from `dev-workflow`.

Never commit directly to `main` or `dev-workflow`.

## Workflow

1. Every task must correspond to a GitHub Issue with acceptance criteria, dependencies, and complexity estimate.
2. Cut a branch from `dev-workflow` named after the issue.
3. Create a git worktree so parallel work stays isolated:
   ```
   git worktree add ../mnemo-<issue>-slug -b feature/<issue>-slug dev-workflow
   ```
4. Implement only the scope of that issue. Small atomic commits.
5. Push the branch. Open a PR targeting `dev-workflow`. Reference the issue in the PR body.
6. CI must pass (`swift build`, `swift test`) before merge.
7. Merge with squash. Delete the branch. Remove the worktree.
8. Close the issue.

## Parallel work

Independent issues may run in parallel worktrees (up to 3–5 concurrent). Never share a working directory between branches.

## Pull Requests

Every PR must:
- solve exactly one issue
- link the issue with `Closes #<n>`
- be small enough to review in one sitting
- pass CI (build + tests)
- pass lint / type checks

Large features get split into multiple smaller PRs.

## Conflict resolution

If two branches touch the same subsystem, pause the lower-priority one, land the prerequisite, rebase the blocked branch onto latest `dev-workflow`, continue.

## Testing

Non-UI code should have XCTest coverage (target: 60%+ post-#52). Tests live in `Tests/`.

## CI

CI runs on macOS via `.github/workflows/ci.yml` (added separately — requires the `workflow` OAuth scope which the automation account lacks). Locally:

```
swift build
swift test
```
