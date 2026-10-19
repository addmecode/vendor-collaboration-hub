# Vendor Collaboration Hub — Orchestrator Prompt

## Objective and sources

Implement exactly one task from section **14. Delivery plan** in
`Docs/project-doc.md` per implementation run. That document defines the project's
business behavior, architecture, task deliverables, acceptance criteria, and
dependencies. Execute the selected task using the shared workflow in
`.opencode/agents/orchestrator.md`.

Use these project-relative configuration sources rather than copying their values:

- `.AL-Go/settings.json`: application/test folders and CI analyzers;
- `.AL-Go/algo.ruleset.json` and the applicable `.vscode/settings.json`: analyzer rules;
- each configured project's `app.json`: identity, versions, dependencies, and ID ranges;
- `vendor-collaboration-hub/.vscode/launch.json`: application publication context;
- `Test/.vscode/launch.json`: test publication and execution context;
- `.github/workflows/`: independent CI checks described in project documentation §12.

Read only the documentation sections and configuration relevant to the selected
task. If the intended design and current configuration materially disagree,
report the discrepancy and ask for direction before changing the affected behavior.

## Task selection and scope

1. Read section 14 of `Docs/project-doc.md`.
2. Select the task explicitly requested by the user; otherwise select the first
   task in plan order whose status is not `DONE`.
3. Treat `DONE` tasks as implemented. Do not implement them again. If an explicitly
   requested task is already `DONE`, report that fact and ask whether a correction
   is intended. If all tasks are `DONE`, report that the plan is complete and make
   no implementation changes.
4. Check the selected task's dependencies. If a required dependency is incomplete,
   report the blocker and ask for direction; do not silently select another task
   or implement the dependency in the same run.
5. Read the selected task's referenced design sections and its **Delivers** and
   **See it work** criteria. Include the cross-cutting requirements of section 14.
6. Implement only that task and strictly necessary supporting changes. Do not
   implement behavior assigned to later tasks or start a second task in this run.

## Required completion gates

- The selected deliverables and acceptance criteria are implemented, including
  applicable permissions and fixtures required by section 14.
- For AL changes, affected projects compile successfully with their configured
  analyzers, and relevant AL diagnostics have no unresolved errors.
- For executable AL changes, affected application/test artifacts are published
  to the configured sandbox and relevant automated tests pass. Use the affected
  project and test selection procedures in `al-testing`; unrelated suites are
  not a completion requirement for this run.
- The independent scoped review has no unresolved in-scope findings.
- The actual user-facing verification route is checked against the final
  implementation. An entry point deliberately assigned to a later task may be
  unavailable if this task's own acceptance criteria do not require it; report
  that limitation and the available automated-test alternative. A missing entry
  point required by this task is an implementation gap.
- For documentation/configuration-only tasks, verify affected references,
  configuration syntax, and the task's specified checks. Require AL build,
  publication, and tests only if the change affects those artifacts or behavior.
- For non-AL deliverables, use the checks specified by the selected task and
  applicable design sections. Resolve missing tooling or validation requirements
  before claiming completion.

CI remains a separate repository gate. No commit or push is authorized to obtain
a CI result during this run; report CI as pending unless an actual applicable run
provides evidence.

## Project-specific completion action

Change only the selected task's **Status** cell in section 14 of
`Docs/project-doc.md` to `DONE` after all applicable completion gates pass and
acceptance criteria are satisfied. Preserve the other task rows and statuses.
Do not mark incomplete, failing, blocked, or unresolved work as `DONE`. If a
required check cannot be completed, leave the status unchanged and identify the
blocker and outstanding checks in the report.

## Final report

1. **Business impact:** what a Business Central user can now do or what the
   application does differently, affected records/process states, and limitations.
2. **Task and files:** selected task number/title, main changed files, and whether
   its status was changed to `DONE`.
3. **Validation:** diagnostics, compilation/publication results, named codeunit/test
   method results, and scoped review outcome. Identify pending or blocked gates.
4. **Assumptions and risks:** unresolved decisions, residual risks, and coverage gaps.
5. **Manual verification:** prerequisites, required permissions, the actual
   page/action/API/integration entry point, steps, and expected observable results.
   If an end-to-end route is unavailable, name the missing entry point and whether
   it is future-task work or an in-scope gap. Give the available automated-test
   alternative by codeunit and method, or state that none exists.

## Git policy

Do not commit, push, amend, reset, discard, or overwrite the user's existing work.
Preserve unrelated changes and existing staging. The user reviews the working tree
and creates the commit manually.