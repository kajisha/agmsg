# agmsg for Devin CLI

Devin CLI is supported for **manual and turn/off delivery workflows**.

`monitor`, `both`, and `spawn devin-cli` are not supported in this release. Devin CLI can participate in an agmsg team alongside Claude Code, Codex, Gemini CLI, and other CLI agents.

## Install

**Alongside Codex (typical setup):**

```bash
bash <(curl -fsSL https://agmsg.cc/install.sh)
```

When `~/.config/devin/` already exists, the installer automatically places
a Devin CLI-typed `SKILL.md` at `~/.config/devin/skills/agmsg/SKILL.md`
without touching the shared `~/.agents/skills/agmsg/SKILL.md` (which stays
Codex-typed). This is the recommended approach for mixed Codex + Devin CLI teams.

**Devin CLI-only (no Codex):**

```bash
bash <(curl -fsSL https://agmsg.cc/install.sh) --agent-type devin-cli
```

`--agent-type devin-cli` overwrites the shared `~/.agents/skills/agmsg/SKILL.md`
with the Devin CLI template. Use this only when Codex is **not** installed; it
will break Codex identification if both agents share the same `~/.agents/` path.

From a local clone, substitute `bash <(curl ...)` with `./install.sh`.

The installer places a Devin CLI-typed `SKILL.md` at
`~/.config/devin/skills/agmsg/SKILL.md`. This is the global skill path
Devin CLI reads and takes priority over the shared
`~/.agents/skills/agmsg/SKILL.md` (which is Codex-typed). Without this,
Devin CLI would pick up the Codex template and identify itself as `codex`.

Devin CLI skill search order (first match wins):
1. `.devin/skills/<name>/SKILL.md` — project-local
2. `~/.config/devin/skills/<name>/SKILL.md` — global config ← installed here
3. `~/.agents/skills/<name>/SKILL.md` — agent-compatible fallback (Codex-typed)

## Join a team

From Devin CLI, run:

```
/agmsg
```

On first run it prompts for a team name and agent name, then joins you to the team. Choose delivery mode `turn` or `off` when prompted.

Or join directly from the shell:

```bash
~/.agents/skills/agmsg/scripts/join.sh <team> <agent_name> devin-cli "$(pwd)"
~/.agents/skills/agmsg/scripts/delivery.sh set turn devin-cli "$(pwd)"
```

## Common actions

Check inbox:

```
/agmsg
```

Send a message:

```
/agmsg send claude check this draft
```

Show team members:

```
/agmsg team
```

Show message history:

```
/agmsg history
```

## Delivery modes

| Mode      | Supported | Notes |
|-----------|:---------:|-------|
| `turn`    | ✓         | Stop hook runs check-inbox after each assistant turn |
| `off`     | ✓         | Manual `/agmsg` only |
| `monitor` | ✗         | Requires Monitor tool — not available in Devin CLI |
| `both`    | ✗         | Requires monitor |

Switch mode:

```
/agmsg mode turn
/agmsg mode off
```

Requesting `monitor` or `both` returns an error:

```
Error: 'monitor' mode is not supported for devin-cli (supported: turn off).
```

## Spawn

`spawn devin-cli` is not supported. Spawn is limited to `claude-code` and `codex`.

## Typical team setup

```text
tmux
├─ Claude Code        Main implementation — monitor mode
├─ Codex              Review / design checks — turn mode
├─ Devin CLI          Local tasks and coding — turn mode
└─ agmsg SQLite       Shared message store
```

Devin CLI is well-suited for tasks such as:
- Multi-file refactors and implementation
- Test and build automation
- Code review and documentation updates

## Known limitations

- No real-time push delivery (`monitor` mode requires Claude Code's Monitor tool)
- No `spawn devin-cli` support
- No `actas`/`drop` exclusivity locks (Devin CLI has no session-id environment variable)

These may be addressed in future releases.
