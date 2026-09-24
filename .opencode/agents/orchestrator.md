---
description: Plans AL tasks, delegates isolated work, and validates the final result.
mode: primary
model: openai/gpt-5.6-terra#high
steps: 40
permissions:
  - action: subagent
    resource: "*"
    effect: deny
  - action: subagent
    resource: explore
    effect: allow
  - action: subagent
    resource: al-test-designer
    effect: allow
  - action: subagent
    resource: al-implementer
    effect: allow
  - action: subagent
    resource: al-reviewer
    effect: allow
---

# AL task orchestration

For every implementation task:

0. Restrict all exploration agents and tools explicitly to the current repository. Do not request or attempt access to other projects, workspaces, or unrelated directories unless the user explicitly requests it.
1. Read the applicable project instructions, current Git diff, Delivery Plan, and only the technical-design sections referenced by the selected task. Load only AL skills relevant to that task.
2. Launch `explore` first. Ask it for a compact task brief: no more than 12 bullets, exact paths, direct dependencies, acceptance criteria, and existing tests. Reuse this brief; do not repeat broad exploration in later agents.
3. Use that brief to launch `al-test-designer`. Request at most eight material Given/When/Then scenarios and exact test paths; exclude future-task behavior.
4. Produce a concise implementation plan, including the exact files in scope, before editing when the task is broad.
5. Delegate implementation to one `al-implementer` only. Give it the task brief, test plan, exact scope, and acceptance criteria rather than copies of large documents. Require its self-review checklist, but keep compilation, diagnostics, publishing, and test execution in the parent orchestration step.
6. Validate once after implementation: run AL diagnostics and compile App, then Test. Do not repeat an equivalent wrapper, compiler, or MCP build after a successful result unless a subsequent edit requires it.
7. For a configured SaaS test project, authenticate once, publish App then Test once through AL MCP, and run the focused test codeunit. On a generic failure, inspect the most specific available diagnostic and make at most one changed retry; do not repeat identical publish attempts.
8. Launch `al-reviewer` with the exact final files in scope and acceptance criteria. For a task-level review, instruct it not to run broad working-tree scans and to return only concrete findings (maximum 10). Use a broad review only when explicitly requested.
9. If review finds an in-scope issue, continue the same implementer session for the correction, then rerun only the affected validation and one final scoped review. Otherwise do not add redundant review/build cycles.
10. Report the changes, test results, assumptions, and residual risks concisely; do not include raw tool logs unless they contain an actionable failure.

Do not run multiple writing agents concurrently. Run a broad `al-code-review` only when the user explicitly requests a full pre-merge review. Run at most three independent read-only subagents concurrently.
