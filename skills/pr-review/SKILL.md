---
name: pr-review
description: Review a pull request in a Laravel (PHP 8) + React codebase for bugs that reach production. Use when the user says "/pr-review 1234", "review this PR", "PRレビューして" or gives a PR URL. Fetches the diff, checks it against a production-bug checklist, runs syntax checks, and drafts review comments. Posts to GitHub only after the user approves.
---

# PR review

Find what will break in production, not style nits. Each finding must point at a line and say what goes wrong for a user.

## Inputs
- PR number or URL. Repository comes from the current git remote unless given.
- GitHub access: `gh` if installed, otherwise the REST API with a token from `git credential fill` (keep it in-process; never print it).

## 1. Collect
- PR meta, changed files and patches (`/pulls/{n}`, `/pulls/{n}/files`), existing review comments and reviews.
- Fetch the head locally without touching the working tree: `git fetch origin pull/{n}/head:pr-{n}`, then `git show pr-{n}:<path>` / `git diff <base>...pr-{n}`.
- Read the full functions around each hunk, not just the hunk.

## 2. Checklist (in priority order)
1. **State written before the side effect succeeds**: a flag/row/path saved, then the work that justifies it fails inside a `try/catch` that only logs. Result: data claims something that doesn't exist.
2. **Ignored return values**: `Storage::put()` returns false instead of throwing, `update()` counts, API wrappers that return `{success:false}` instead of throwing.
3. **`env()` outside `config/`**: returns null once `php artisan config:cache` runs in production.
4. **Ordering and races**: client vs server timestamps, "latest" chosen by a client-sent value, cache keys built from unvalidated input, missing numeric guards.
5. **Queries**: N+1 in loops, new `WHERE`/`ORDER BY` without an index, wide transactions holding locks during HTTP calls or rendering.
6. **Copied components**: when a file is a "lighter copy" of another, diff them and check every guard the original has (permissions, contract checks, feature flags).
7. **React**: hooks after an early `return`, missing effect dependencies, state not reset when the selected item changes, effects without cancellation.
8. **Deploy safety**: anything that crosses tasks during a rolling deploy (calls to the public URL from the server, file paths shared between web and queue).

## 3. Syntax checks
Run `scripts/check_syntax.sh <files...>` on the PR versions of changed files (export them with `git show` into a temp dir). It runs `php -l` (local PHP or the `php` Docker image) and esbuild's `transformSync` for `.js/.jsx/.ts/.tsx`.

## 4. Report
```
Summary: <2 lines>
| Severity | file:line | Problem (what the user sees) | Suggested fix |
Syntax: <results>
Existing review comments: <addressed / not addressed, with the commit>
Verdict: approve / request changes
```
Severity: blocker (data loss, wrong data, crash) / major (user-visible bug) / minor / nit. Drop anything you can't point at.

## 5. Post (only after approval)
Post one review with `event: COMMENT` (or `REQUEST_CHANGES` when asked) and inline comments on the exact lines. Never approve on behalf of the user unless asked.
