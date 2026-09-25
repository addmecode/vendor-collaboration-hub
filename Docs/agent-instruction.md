# AI Agent Implementation Instructions

## Objective

Implement the project according to the specification in `docs/tech.md`.

Complete exactly one task from the **Delivery Plan** section during each run.

## Required skills

Before inspecting or changing AL code, read and follow these skills:

- `al-language-server`
- `al-testing`

Use `al-language-server` for AL code navigation, implementation, compilation, diagnostics, and the required post-implementation code review. Use `al-testing` for creating and evaluating relevant automated tests.

## Task selection

1. Read the **Delivery Plan** section in `docs/tech.md` and the technical-design sections referenced by the selected task. Do not read unrelated sections in full.
2. If the user explicitly identifies a task to implement, select that task.
3. Otherwise, scan the Delivery Plan from top to bottom and select the first task whose status is not `done`.
4. Treat a task with status `done` as already implemented. Do not implement it again.
5. Implement only the selected task during the current run. Do not start another Delivery Plan task after completing it.
6. If every task has status `done`, make no implementation changes and tell the user that the Delivery Plan is complete.

## Implementation workflow

1. Inspect the existing implementation, relevant tests, project configuration, and the selected task's acceptance criteria before editing files.
2. Implement all requirements of the selected task while keeping changes limited to that task and any strictly necessary supporting changes.
3. Add or update automated tests when required to verify the implemented behavior. Follow the `al-testing` skill.
4. Perform a code review of all changes made during the run. Follow the `al-language-server` skill and correct every issue found that is within the selected task's scope.
5. Compile the affected AL project or projects according to the `al-language-server` instructions.
6. If compilation fails, diagnose and fix the cause, then repeat the code review and compilation. Continue this cycle until compilation succeeds.
7. Only after the implementation, code review, and compilation have all succeeded, update the selected task's status in the Delivery Plan in `docs/tech.md` to `done`.
8. Stop after completing that one task and report:
    - which task was implemented;
    - the main files changed;
    - the compilation result;
    - confirmation that its Delivery Plan status was changed to `done`;
    - a concise, user-facing summary of the uncommitted changes and their business impact;
    - a manual test checklist for a Business Central user, with prerequisites, steps, and expected results. State explicitly when an end-to-end scenario cannot yet be exercised because a dependent Delivery Plan task is not complete, and give the available automated-test alternative.

## Failure and blocking rules

- Never mark a task as `done` if its implementation is incomplete, the code review has unresolved issues, or compilation fails.
- If compilation cannot be run because of a genuine external blocker, exhaust safe in-scope remedies, leave the task status unchanged, and clearly report the blocker and the commands or checks that remain to be completed.

## Git policy

Do not commit any changes. The user will review the working tree and create the commit manually.

Do not amend, reset, discard, or overwrite the user's existing uncommitted changes. Keep unrelated changes intact.
