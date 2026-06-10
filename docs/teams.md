# Team operations — reference

The [README](../README.md) covers the slash-command flow most users need. This page is the reference for the underlying shell scripts and the less common team operations: leaving, renaming, joining the same team from a second project, and clearing a project's registrations.

All scripts live under `~/.agents/skills/agmsg/scripts/` (or `<cmd>` if you installed under a different command name).

## How identity works

Agents join teams by **identity**: `(agent name, team)`. Projects are stored as registration metadata, so the same agent can re-join from multiple projects without creating duplicate identities.

You can re-join the same team with the same agent name from a second project, and agmsg will keep one identity and add a registration record for the new project. This is what makes "same agent on two laptops / two repos" work without forking your inbox.

## Joining without the slash command

The slash command (`/agmsg` on Claude Code, `$agmsg` on Codex / Gemini CLI / Antigravity) does this for you and is the recommended path. For automation, CI, or scripts, you can call `join.sh` directly:

```bash
~/.agents/skills/agmsg/scripts/join.sh <team> <agent_name> <agent_type> <project_path>
# example
~/.agents/skills/agmsg/scripts/join.sh myteam alice claude-code /path/to/project
```

To register the same identity from a second project:

```bash
~/.agents/skills/agmsg/scripts/join.sh myteam alice claude-code /path/to/project-a
~/.agents/skills/agmsg/scripts/join.sh myteam alice claude-code /path/to/project-b
```

Both projects now route messages addressed to `alice` to whichever session is live, without creating a second `alice` identity.

## Multiple agent names on one project

You can register more than one name in the same project (e.g. `cc` and `reviewer`). The slash command detects this and asks which one to use for the session:

```bash
~/.agents/skills/agmsg/scripts/join.sh myteam cc claude-code /path/to/project
~/.agents/skills/agmsg/scripts/join.sh myteam reviewer claude-code /path/to/project
```

For the case where you want one workspace to play multiple *roles* (e.g. a `tech-lead` identity and a `biz-analyst` identity sharing the same checkout), use `actas` / `drop` instead — see [docs/actas.md](actas.md).

## Leaving a team

```bash
~/.agents/skills/agmsg/scripts/leave.sh <team> <agent_name>
```

Removes the agent's identity from the team entirely. All registrations across all projects for that `(team, agent)` pair are removed. Messages already in the DB are kept (history is preserved).

## Renaming a team

```bash
~/.agents/skills/agmsg/scripts/rename-team.sh <oldteam> <newteam>
```

Moves the team directory, updates `config.json`, and migrates messages so history is preserved under the new name.

**Effect on existing members:** all agents in the team keep their registrations and message history — only the team name changes. Any session that has already cached the team name (e.g. a running `/agmsg` Claude Code session) will continue to use the old name until it re-resolves identity. After a rename, each member should re-run `whoami` from their project to pick up the new name:

```bash
~/.agents/skills/agmsg/scripts/whoami.sh "$(pwd)" claude-code
```

## Clearing a project's registrations

If you want to clear the current project's registrations without leaving the team identity entirely (e.g. you're moving the project, or you want a clean rejoin):

```bash
~/.agents/skills/agmsg/scripts/reset.sh <project_path> <agent_type>
# example
~/.agents/skills/agmsg/scripts/reset.sh /path/to/project-b claude-code
```

To remove a single role's registration on this project (leaving other roles untouched):

```bash
~/.agents/skills/agmsg/scripts/reset.sh <project_path> <agent_type> <agent_name>
```

This is what `/agmsg drop <name>` calls under the hood.

## See also

- [docs/actas.md](actas.md) — multi-role mechanics (`actas` / `drop`), exclusivity locks, Codex caveat.
- [README — Shell (any agent)](../README.md#shell-any-agent) — the script quick-reference for sending, inbox, history, delivery mode.
