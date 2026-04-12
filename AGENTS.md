# AGENTS.md

## Scope

These instructions apply to Codex-driven changes in this repository.

## Commit Rules

- Use Conventional Commits for every commit.
- Preferred format: `type(scope): summary`.
- Keep the `type` and `scope` lowercase.
- Make every commit atomic: one logical change per commit.
- Do not mix unrelated fixes, refactors, docs, or test-only work into the same commit unless they are required to ship the same logical change safely.
- If a local, unpushed commit does not follow the convention or is not atomic, rewrite or split it before finishing the task.

## Required Review Workflow

- Every code change must go through sub-agent code review before it is finalized.
- Use at least two review sub-agents for every implementation task.
- The reviewers must come from different perspectives whenever possible. Examples: correctness, regression risk, UX, performance, security, API compatibility, test quality.
- Do not stop after a single review round if a reviewer finds a real issue or a credible risk.
- Fix the issues, rerun the relevant verification, and send the updated diff back through review.
- The minimum reviewer set for a normal implementation task is two reviewers. Use more when the change is risky or spans multiple domains.
- If reviewer conclusions conflict, resolve the blockers and request another review round. Add a tie-break reviewer when the conflict cannot be closed quickly.
- If a requested reviewer becomes unavailable, replace that reviewer with another reviewer covering the same perspective.
- Repeat this review-and-fix cycle until the required reviewer set for the task reports no blockers.
- Do not finalize, commit, or present the work as complete while any required reviewer still has an unresolved blocker.
- If sub-agents are unavailable in the current environment, treat that as a blocking condition for finalization and explicitly report it.

## Upstream-Aware Review

- Some code in this repository depends on behavior, APIs, specs, event formats, or UX semantics inherited from the upstream OpenCode project: [anomalyco/opencode](https://github.com/anomalyco/opencode).
- When a change depends on upstream behavior, an upstream-aware code review sub-agent is mandatory in addition to the normal local reviewers.
- The upstream-aware reviewer must inspect the relevant upstream code or documentation and explicitly evaluate compatibility, drift risk, and fallback behavior.
- This upstream-aware review is required when the change does any of the following:
  - adds, removes, or changes behavior that calls upstream-defined endpoints or session actions
  - parses, transforms, or renders upstream-defined event payloads, request payloads, or capability data
  - changes slash-command, shell, config, model-selection, or session UX that is intended to mirror upstream behavior
  - adds compatibility logic, fallbacks, or probes for upstream server versions or transport behavior
- Treat the change as upstream-dependent by default when touching protocol or transport behavior, capability probing, server compatibility, session lifecycle actions, event stream handling, slash-command handling, or config/model-selection rules tied to upstream semantics.
- If it is unclear whether a change is upstream-dependent, request the upstream-aware review anyway.
- If the relevant upstream code or documentation cannot be inspected, treat that as a blocking condition for finalization.
- Assume the upstream default branch is `dev` unless current upstream evidence shows otherwise.

## Verification After Review

- After each review-driven fix, rerun the narrowest meaningful verification first.
- Before finalizing, run the full targeted verification needed for the touched area.
- If a reviewer identifies a missing regression test, add it unless there is a documented reason not to.
