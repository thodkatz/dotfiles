# dotfiles — Developer Reference

> This file is `AGENTS.md`, not `CLAUDE.md`: Codex reads `AGENTS.md` natively, and Claude Code reads it when
> no `CLAUDE.md` exists. `README.md` is the people's manual (installing each package, tmux and `fleet`), kept as
> its own file: read the section your task touches, not the whole of it.

<!-- methodology: entry-point -->
**This file is the entry point, not the whole manual.** It holds only what every session needs: the working
conventions, current work, the shape of the workflow and how to run things. Everything else lives in the files
below; read one only when your task matches its *Read when* column. AGENTS.md and these files are one
instruction set: each rule lives in exactly one of them, so update the file that owns it, never a copy.
<!-- /methodology: entry-point -->

## Read on demand

<!-- methodology: read-on-demand -->
| File | Read when |
|---|---|
| [`.methodology/shared/guides/sessions-and-context.md`](.methodology/shared/guides/sessions-and-context.md) | the context-budget hook fires, you start a session from a handoff, you start an investigation or audit, or you hand work to a subagent: the budget, the start routine, mid-unit handoffs, investigation scope |
| [`.methodology/shared/guides/development-workflow.md`](.methodology/shared/guides/development-workflow.md) | you start a change, spike or spec, or claim, open, review, advance or merge any PR: modes, stages, handoffs, deferred items, claiming, local or CI review, merge and cleanup, slicing, agent automation |
| [`.methodology/shared/guides/forge-github.md`](.methodology/shared/guides/forge-github.md) | you run a step on the forge (claim, ready, comment, label, merge, issues) or check what must pass before a merge: the command for each |
| [`.methodology/shared/guides/spec-and-plan-layout.md`](.methodology/shared/guides/spec-and-plan-layout.md) | you write, extend or split a spec or plan, add a clarification, hand a slice to a subagent, or work from a spec or plan that is a directory |
| [`.methodology/shared/guides/tooling-gotchas.md`](.methodology/shared/guides/tooling-gotchas.md) | a command or tool fails (`gh`, `fj`, `git`, Claude Code, the runners, agent-action's CI reviewers): known failures in every repo, and the command that works; then this machine's notes, the `.methodology/machines/<kind>.md` the session-start hook names (`methodology: machine <kind>, …`), and this repo's own for it, `docs/knowledge/machines/<kind>.md`, when it has one |
| [`docs/README.md`](docs/README.md) | you look for a spec, plan, investigation or reference: the index of everything under `docs/` |
| [`docs/knowledge/README.md`](docs/knowledge/README.md) | you start non-trivial work in an area, or a command or tool fails: as-you-go gotchas and workarounds (see *Project knowledge*) |
| [`BACKLOG.md`](BACKLOG.md) | you start a unit, triage, or look for known unscheduled problems |
<!-- /methodology: read-on-demand -->

| File | Read when |
|---|---|
| [`README.md`](README.md) | you change a package or how it is installed, or touch tmux or `fleet`: the stow commands, the tmux keys and plugins, how `fleet` is set up, run and updated on the laptop and the hosts |
| [`docs/superpowers/specs/2026-11-05-tmux-fleet-design.md`](docs/superpowers/specs/2026-11-05-tmux-fleet-design.md) | you change `fleet` or the tmux config: its decisions D1–D15 and clarifications |
| [`docs/superpowers/plans/2026-11-05-tmux-fleet.md`](docs/superpowers/plans/2026-11-05-tmux-fleet.md) | you need `fleet`'s global constraints (pane options, hint format, ssh options) or how its tests were built |

## Keep each session small

<!-- methodology: keep-sessions-small -->
Context is the scarce resource: every request re-reads the whole conversation, and quality drops as it grows.
So a session does one bounded piece of work and hands off:

- **Budget: `AGENT_CONTEXT_BUDGET` tokens of context per session** (150k in `.claude/settings.json`). Past it, the
  context-budget hook tells you so; the status line (`.methodology/shared/claude/statusline.sh`) shows it
  all along. Finish the current step, write the handoff (a new file in the plan's `handoffs/`, made by
  `methodology handoff new <dir> <slug>`, a knowledge note or the investigation's output),
  commit, and end the session, **even in the middle of a unit**. The next session
  starts fresh from the handoff; with `AGENT_AUTO_CONTINUE=true`, start it yourself with
  `methodology next <handoff path>` (under `chain.sh`, in this terminal or a new `dtach`
  one), then stop. A new parallel session (a fresh unit's worktree) starts only with `methodology next --new
  "<prompt>"`, never a bare `claude`/`claudeN`: only `chain.sh` moves a session off an exhausted account.
- **A fresh session starts the same way every time:** read the handoff (only the newest:
  `methodology handoff newest <plan>/handoffs` when the unit has a plan, else
  `methodology handoff newest docs/handoffs`, if there is one), `git status`, `git log --oneline -5`, `methodology worktree --prune` (merged units' worktrees, and the main checkout up to its upstream),
  `BACKLOG.md`'s *Next* (due on any track, or waiting on the user), then work.
  A user saying *continue* (*continue with the handoff*) means this routine, in this session: `methodology next`
  runs only at the budget, and `methodology next --unit` only at a unit's end.
- **Other sessions are the supervisor's, not yours.** Don't watch or poll other sessions with `methodology status` (one
  check that a session you just started came up is fine), and rescue one only when the user asks or the
  supervisor can't reach it: the supervisor's timer (`supervise.sh`) acts on unattended ones, a person on their
  own. A handoff never asks the next session to watch one (`sessions-and-context.md`, *Other sessions are not a
  session's work*).
- **Investigations and audits are scoped.** Each one answers a written question into a file. Wide reading
  goes to subagents, which return short summaries; a repo-wide audit is a fan-out of scoped subagent tasks
  plus one synthesis session.

Details and the reasons: `.methodology/shared/guides/sessions-and-context.md`.
<!-- /methodology: keep-sessions-small -->

## Write for progressive disclosure

<!-- methodology: progressive-disclosure -->
The same rule applies to what you write. An agent should be able to read a short index and then open only the
part its task needs. Keep this file short: a rule that only some tasks need goes into the file for those tasks,
with a row in *Read on demand* if it starts a new guide. Don't load a whole spec, plan or `docs/` directory "for
context": read its index or the section your unit names.

- **Parts hold the current design; history lives apart.** A change rewrites the spec section or plan task it
  amends; the reason goes in the spec's clarifications with a status (`folded` or `superseded by …`), and
  progress and provenance go in the plan's slices table and handoffs. Never two live texts for one decision.
- **A change updates every doc it makes stale, in the same commit.** When you remove, rename or reverse
  something (a path, section, command, flag, label, rule or behaviour), grep the repo for it and rewrite each
  current-design text that still says the old thing: `AGENTS.md`, guides, knowledge notes, `BACKLOG.md`, spec
  sections, open plan tasks. History (handoffs, clarifications, investigations, evidence, merged slices) stays
  as written. A doc the diff left stale is a review finding.
- **Large specs and plans are directories**: a `README.md` index plus one file per section or slice, past ~400
  lines for a spec and always for a plan with more than one slice.
- **Whatever grows by appending is built to grow**: a one-line-per-item index, detail apart, a pruning rule.

History apart, large documents, growth, the clarification template and the layout: `.methodology/shared/guides/spec-and-plan-layout.md`.
<!-- /methodology: progressive-disclosure -->

## Working Conventions

<!-- methodology: working-conventions -->
- **Commit after each edit.** After completing an edit to the codebase (one coherent change, not each file
  write), make a git commit scoped to that change, with a clear, descriptive message.
- **Sign-off: kept.** Sign off every commit (DCO): always commit with `git commit -s`, with a `Signed-off-by:`
  line matching the commit author; the forge sheet's *Before a merge* says what checks it. This goes alongside,
  not instead of, the `Co-Authored-By:` trailer *Attribution* names. To fix a branch that's missing sign-offs:
  `git rebase <base> --signoff`, then `git push --force-with-lease`.
- **Attribution: an agent's commit and forge text name its tool.** End the commit message with one
  `Co-Authored-By:` trailer unless the harness already appends one (Claude Code does; Codex does when its git
  attribution feature is on): an opencode session adds `Co-Authored-By: opencode <noreply@opencode.ai>`, a codex
  session that added none itself `Co-authored-by: Codex <noreply@openai.com>`. Alongside, not instead of, any
  sign-off. A PR body, PR comment, review or reply the agent posts ends with one line naming its tool, after any
  `Checks:` line: the footer the harness gives for PR bodies (Claude Code:
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`), on comments too, and once, not again where the
  harness already added it; with none, `🤖 Generated with Codex` or `🤖 Generated with opencode`. The agent posts
  as the user, and without it the comment reads as theirs. A script's own report (the supervisor's) is not the
  agent's, and carries none.
- **Spawn subagents freely.** Agents working in this repo have standing permission to spawn subagents without
  asking. This overrides any harness default to spawn only on request. Follow the superpowers skills'
  recommended path:
  - Implement a plan's slice with `superpowers:subagent-driven-development`: a fresh implementer subagent per
    task, the per-task reviews, and a whole-branch final review on the most capable model before the PR opens.
  - Use read-only search agents (`Explore`, `general-purpose`) for broad searches and for scanning
    `docs/knowledge/`, so the reading stays out of your context.
  - Use `superpowers:dispatching-parallel-agents` for independent investigations.
- **Don't stop for approval inside the workflow.** The loop runs unattended: no in-chat check-ins between
  tasks, slices or review rounds. The one approval a full-mode track waits for is its spec PR's `approved` label
  (`large-slice` past the hard size limit is the user's too: `development-workflow.md`, *Slicing implementation*).
  Otherwise stop only for
  what the loop can't decide: destructive or irreversible actions outside it, a plan broken beyond a ledgered
  ruling (every way forward a guess), or quota-heavy runs, which *Setup* lists. That list is closed
  (`development-workflow.md`, *Gates*, says what is not a gate), even where a plan or handoff says to ask: decide
  the rest and record the ruling. Never wait by asking in chat: a gate waits on its PR as
  `development-workflow.md`'s *Gates* says: one comment, the `waiting-on-user` label, and a watcher that wakes the
  session when the user answers.
- **Never edit `.methodology/`.** It is a link to the machine's read-only install of agent-methodology. Edits
  there are refused (the files are read-only) and would reach every repo on the machine. Deviate from a shared
  rule in *Overrides*; carry an improvement to agent-methodology as its own change, then `methodology update`
  (agent-methodology's `UPDATING.md`).
<!-- /methodology: working-conventions -->

- **Stow layout.** Each top-level directory is a stow package mirroring `$HOME` (`xorg-conf` mirrors `/etc`),
  with `--dotfiles`: a path segment `dot-foo` is linked as `.foo`. A new file goes under its package's mirrored
  path, never at the repo root; a new package is added to `README.md`'s install command.
- **`README.md` documents every user-facing change** (a key, a command, a setup step), in the same commit.
- **The tmux config is shared** with the NixOS hosts, which link `tmux.conf` to their checkout of this repo
  (nixed): a change in `tmux/` reaches them on their next pull. A plugin added or removed also needs nixed's
  plugin list changed, as a nixed PR.

## Overrides

Where this repo deviates from a shared guide, one line each: "In this repo, X instead of `<guide>`, *Section*,
because Z." This file wins over the guides in `.methodology/shared/guides/`.

- In this repo, the trunk is `master` instead of `main` wherever the shared guides say `main` or `origin/main`
  (`development-workflow.md`, throughout), because the hosts' checkouts track `master`. The user's decision,
  2026-11-07.
- In this repo, no `pr-checks` workflow instead of `forge-github.md`, *Before a merge*, because dotfiles is public
  and agent-action, which it runs, is private (GitHub can't resolve it: "Unable to resolve action
  `thodkatz/agent-action`, not found"). The local review round checks the same rules: slice size, a spec's
  `approved`, clarification status, carried-forward text. 2026-11-07.

## Current work

One line per active track: where it stands, the next unit, and where its handoff is. This section only points
to things. Who is working on what is shown by the open PRs, not here (*Claiming a unit* in the workflow guide).
Each unit's PR updates its track's line; the last slice removes it.

- **Not scheduled**: `BACKLOG.md` holds every deferred item without a slice; its *Next*, the ones due soon or
  waiting on the user.

## Project in brief

The user's dotfiles for an Arch laptop (i3, polybar, alacritty, zsh, nvim, doom, …) and, for tmux, the NixOS
hosts too, managed with GNU Stow (*Working Conventions*). The one piece of code is `fleet`
(`tmux/dot-local/bin/fleet`, bash): it builds a tmux session with every agent session on every host's microVM
guests, reading each host's `/etc/agentvm/projects.json` and each guest's supervisor `status.sh --json` over ssh.

- **Nothing here is deployed by a merge.** The laptop and each host apply it by `git pull` in their checkout
  (`~/repos/dotfiles`), plus `stow -R <package>` for a new file; a running `fleet` restarts its overview and hint
  loops on `prefix F` only when their version stamp in `fleet` changed, so a change to what a loop does bumps
  its stamp (`README.md`, *Update and run*).
- **A session in a guest can't reach the laptop or the hosts' tmux**: test `fleet` with the bats suite, which
  stubs ssh, systemctl and ip (`tests/stub`) and answers from `tests/fixtures`, never a real host.

## Development workflow

<!-- methodology: development-workflow -->
Pick the lightest mode that fits, and move up when the work turns out bigger:

- **Direct**: you can describe the diff in one sentence (typo, one-line doc fix, config tweak). Commit to `main`.
- **Change**: a few files, clear approach, no contract others rely on. One PR `change/<slug>`, plan in its body.
- **Spike**: you don't yet know what works. A written question and budget in `docs/investigations/<topic>.md`,
  throwaway code on `spike/<topic>` (never merged); the output is the finding and a recommendation.
- **Full**: more than one slice, a contract or schema change, or costly rework. Three sequential stages, each
  its own branch cut from `origin/main` and its own PR:
  1. **Spec**: `spec/<topic>`, written by the `brainstorming` skill into `docs/superpowers/specs/`. Every
     decision names its acceptance check. **The user approves it** (the `approved` label).
  2. **Plan**: `plan/<topic>`, written by the `writing-plans` skill into `docs/superpowers/plans/`, with its
     `## PR slices`.
  3. **Implementation**: one small PR per slice, `impl/<topic>-<n>-<slug>`, titled `… (n/N)`.

The rules that bite most often:

- **Claim before you work**: the unit's branch pushed to `origin` plus a draft PR, worked on in its own worktree,
  `.claude/worktrees/<branch, / as ->` of the main checkout (`methodology worktree <branch>`
  makes it; `git worktree list` shows them all). **One PR open at a time per track**, and dependent work waits
  until that PR has merged.
- **One review round, by the reviewer in *Reviewers***: local reviewer subagents, or a CI reviewer and, if it's
  out, the fallbacks there, in order; a mechanical PR (a pointer, copied or regenerated files) has none. Address every finding, then **merge it yourself**
  (*Merge*) once every check the forge sheet lists under *Before a merge* passes (and, for a spec, once the
  user has added `approved`). Clean up the worktree and branch afterwards.
- **Hand off, then chain**: every unit ends with a handoff for the next one, riding in its own PR, and updates its
  track's line in *Current work*. Don't start the next unit in the same session: once the PR merged and cleanup is
  done, write a second, short handoff on `main` that names the unit's own handoff (now on `main`, and the next
  session reads only this one) and adds what only the merge settled (its commit, the review round); commit, push
  and start it with `methodology next --unit <branch> <handoff>` from the main checkout; the track's last unit
  ends with `methodology next --end`. Hand off earlier when the context budget says so. Told to stop ("stop
  here", "finish this, then stop", "pause"), finish the step, commit and push, write a handoff (`methodology
  handoff new`, where the budget's goes), commit and push it, then `methodology next --end`:
  never the handoff form, which chains on.
- **Deferred items land somewhere durable**: rewritten into a planned slice's task text, a new slice, the next
  spec's **Inputs for**, or `BACKLOG.md`. A handoff, PR body or review reply only points.

**Before you start a change, spike or spec, or claim, open, review or advance any PR, read
`.methodology/shared/guides/development-workflow.md`.**
<!-- /methodology: development-workflow -->

## Reviewers

Who runs each PR's review round (`development-workflow.md`, *Review and merge*):

- **`local`**: reviewer subagents in the working session (*Local review* there); no CI reviewer.

## Project knowledge

<!-- methodology: project-knowledge -->
As you work, capture anything you learn that isn't already visible from the code or `git log`: a workaround, a
constraint that isn't obvious from reading the file, why an approach was rejected, a gotcha that cost real time.
Keep an index at `docs/knowledge/README.md`, one line per entry pointing to `docs/knowledge/<topic>.md` (not the
`docs/knowledge/machines/<kind>.md` files below, which the hook names). Skim the index before non-trivial work in
an area; open a linked file only when it's relevant. Write notes alongside the change they relate to; no separate
PR is needed. Don't record what the code or history already shows.

- **When something fails, look before you debug:** grep `docs/knowledge/`,
  `.methodology/shared/guides/tooling-gotchas.md` and the machine's notes (the files the session-start hook names:
  `.methodology/machines/<kind>.md`, and this repo's `docs/knowledge/machines/<kind>.md` when it has one) for the
  command, tool or error text; under `docs/knowledge/machines/`, only this machine's file applies. The next
  session should go straight to the fix someone already found. A failed Bash command does part of it for you: the
  failed-command hook adds the notes and guide sections that share the error's wording (index lines and note
  bodies) to your context. Read what it adds before you debug; when it adds nothing, grep all the same.
- **When you find a workaround, write it down before moving on.** If a command, tool or approach failed and took
  more than one retry to get past, record the symptom (the exact error), the fix, and the command that works.
  Put the command and the exact error text in the index line and the note, so a grep and the hook find it. A
  gotcha in a tool every repo uses, rather than in this project, belongs in `tooling-gotchas.md`; one only this
  kind of machine has, in its `machines/<kind>.md`: carry it to agent-methodology (*Never edit `.methodology/`*),
  and keep a note here until the machine's next `methodology update` brings it in. One only this repo has, and
  only on one kind of machine (a service that needs a workaround there), goes in
  `docs/knowledge/machines/<kind>.md` (`<kind>` is the `AGENT_MACHINE` the hook names), not in `AGENTS.md`, which
  every machine reads.
- **Lessons in a handoff become notes.** A gotcha written only into a handoff or a PR body gets lost;
  write the note and link it from the handoff.
<!-- /methodology: project-knowledge -->

## Setup

Nothing to install in a nixed-microvm guest: `tmux`, `bats`, `shellcheck`, `jq` and `dtach` are on its PATH (on
the laptop: `sudo pacman -S tmux jq fzf bash-bats shellcheck`). The tests, from the repo root, each on a private
tmux server (about four minutes; light enough to run without `methodology heavy`):

```bash
bats tests/              # tests/fleet.bats
shellcheck tmux/dot-local/bin/fleet   # not clean today (SC1010, SC2015, SC2034): don't add new findings
```

After a merge nothing rebuilds here; the PR body says what the user runs on the laptop and the hosts (a pull, a
`stow -R`, `prefix r` / `prefix F`, or nixed's switch for a plugin change). No quota-heavy runs.
