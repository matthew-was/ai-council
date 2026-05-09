# Finish Task

Runs the end-of-task routine after a task reaches `done` status. The PM agent sets `done`
after the user sets `reviewed` — `/finish-task` is the step after that. Covers: moving the
code review file(s) to archive, committing, pushing, optionally opening a PR, and appending
a block to the lab entry draft.

Invoke as: `/finish-task <service> <task-number>`

Examples: `/finish-task frontend 4`, `/finish-task backend 12`

---

## Arguments

- **service**: `frontend` or `backend`
- **task number**: integer

If either argument is missing, ask for it before proceeding.

---

## Workflow

### Step 1 — Verify task status

Read the relevant task file (`documentation/tasks/frontend-tasks.md` or
`documentation/tasks/backend-tasks.md`).
Find the task block (`### Task [N]:`). Check that `**Status**` is `done`.

If the status is anything else, output:

> "Task [N] has status `[current]` — finish-task should only be run after the PM agent
> sets the task to `done`. No changes have been made."

And stop.

### Step 2 — Locate the code review file(s)

Check `documentation/tasks/code-reviews/` for all files matching
`code-review-[service]-task-[N]-*.md`.

- If one or more found: note all filenames and proceed — all will be moved in Step 6.
- If none found: tell the developer no review file was found and ask whether to continue
  without moving one (the remaining steps still apply).

### Step 3 — Update CLAUDE.md

In `CLAUDE.md`, under `## Project Status` → `### Task progress`:

- Update the Done count and the Next task for this service.

Apply these changes automatically without asking for confirmation.

### Step 4 — Confirm commit

Run `git diff HEAD --stat` and `git status` to understand what is staged/unstaged.

Draft a commit message following the project convention:

- First line: `[Service] Task [N] — [task title from task file]`
- Body: 3–6 bullet points covering what was implemented, key decisions, and any
  post-review fixes applied. Include the PR number if already known (it won't be yet —
  omit and note "PR to follow").
- Footer: `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`

Present the draft commit message to the developer and ask:

> "Ready to commit with the message above — confirm? (yes / edit)"

Wait for confirmation before running `git commit`. If the developer says "edit", accept
their revised message and use that instead.

### Step 5 — Move the code review file(s) (if found in Step 2)

Before committing, ensure the archive directory exists:

```bash
mkdir -p archive/code-reviews/[service]
```

Then move all review files found in Step 2:

```bash
mv documentation/tasks/code-reviews/[filename] archive/code-reviews/[service]/
```

Stage them alongside the other changes (`git add`) so they are included in the commit.

### Step 6 — Commit

Run `git commit` with the confirmed message. Record the resulting commit SHA — it is
needed in Step 10.

### Step 7 — Push and PR decision

Ask:

> "Push to remote and open a PR? Options:
>
> 1. Push and open PR → main
> 2. Push and open PR → [other branch] (specify)
> 3. Push only (no PR)
> 4. Skip (neither push nor PR)"

Wait for the developer's answer.

**If option 1 or 2**: push the branch, then open a PR using `gh pr create` with:

- Title: `[Service] Task [N] — [task title]`
- Body: summary of what was implemented, test plan checklist, and the standard
  `🤖 Generated with Claude Code` footer.
- `--base main` (or the specified branch for option 2).

Report the PR URL when done.

**If option 3**: push only (`git push -u origin [branch]`). No PR.

**If option 4**: skip both. Note that the commit exists locally only.

### Step 8 — Append lab entry block

Run `date -u +"%Y-%m-%dT%H:%M:%S"` for the timestamp.

Draft a lab entry block covering:

- What was implemented
- Key architectural or design decisions made during the task
- Any notable review findings and how they were resolved

The `commits` array in the block **must** include the commit made in Step 6 (using its
recorded SHA). Resolve the full hash and construct the GitHub URL:
`https://github.com/<owner>/<repo>/commit/<full-hash>`. If no commit was made (Step 6
was skipped), the `commits` array should be empty.

**Present the draft as formatted markdown prose** — do NOT show raw JSON or escaped
strings. Use the following structure so the content word-wraps naturally:

---

**Lab entry draft**

**Task**: [task title]

**What was implemented**: [prose summary]

**Key decisions**:

- [decision 1]
- [decision 2]
- ...

**Review notes**: [prose summary of review rounds and findings]

**Commit**: [full SHA] — [GitHub URL]

---

Then ask:

> "Append the above block to the lab entry? (yes / edit / skip)"

On confirmation, convert the above to the JSON block format and append to
`~/.claude/lab-entry-draft.json` as defined in the lab-entry skill. If no draft exists,
note it and skip.

### Step 9 — Done

Output a brief summary listing: commit SHA, PR URL (or 'none'), and whether each of
CLAUDE.md and the lab entry were updated or skipped.
