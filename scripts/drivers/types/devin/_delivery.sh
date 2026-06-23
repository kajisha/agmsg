#!/usr/bin/env bash
# devin delivery plug.
#
# Devin CLI reads hooks from `.devin/hooks.v1.json`, whose top-level keys are
# event names (e.g. `Stop`) rather than wrapped in a `.hooks` object like
# Claude Code's `settings.json`. This plug overrides the default JSON
# event-hooks apply so delivery writes the correct shape for Devin CLI.
# Sourced into delivery.sh's context, so SKILL_DIR, resolve_hooks_file,
# sql_readfile_path, and agmsg_sqlite_mem are in scope.

# Strip agmsg-owned entries from a top-level event array in hooks.v1.json.
_devin_strip_event() {
  local path="$1" event="$2"
  local sql_path tmp tmp_sql wrote
  sql_path=$(sql_readfile_path "$path")
  tmp=$(mktemp "${TMPDIR:-/tmp}/agmsg-devin.XXXXXX")
  tmp_sql=$(sql_readfile_path "$tmp")
  wrote=$(agmsg_sqlite_mem "
    WITH src AS (SELECT readfile('$sql_path') AS j),
    out AS (SELECT coalesce(CASE
      WHEN json_extract(src.j, '\$.$event') IS NULL THEN src.j
      WHEN (SELECT count(*) FROM json_each(json_extract(src.j, '\$.$event')) AS s
            WHERE NOT EXISTS (
              SELECT 1 FROM json_each(json_extract(s.value, '\$.hooks')) AS h
              WHERE instr(json_extract(h.value, '\$.command'), '$SKILL_NAME') > 0
            )) = 0 THEN
        json_remove(src.j, '\$.$event')
      ELSE
        json_set(src.j, '\$.$event',
          (SELECT json_group_array(json(s.value))
           FROM json_each(json_extract(src.j, '\$.$event')) AS s
           WHERE NOT EXISTS (
             SELECT 1 FROM json_each(json_extract(s.value, '\$.hooks')) AS h
             WHERE instr(json_extract(h.value, '\$.command'), '$SKILL_NAME') > 0
           ))
        )
    END, '') AS blob FROM src)
    SELECT writefile('$tmp_sql', blob) = length(CAST(blob AS BLOB)) FROM out;
  ") || { rm -f "$tmp"; return 1; }
  [ "$wrote" = "1" ] || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$path"
}

# Add a top-level event entry to hooks.v1.json.
_devin_add_event() {
  local path="$1" event="$2" cmd="$3"
  local sql_path cmd_lit hook_obj entry_sql tmp tmp_sql wrote
  sql_path=$(sql_readfile_path "$path")
  cmd_lit=$(printf '%s' "$cmd" | sed "s/'/''/g")
  hook_obj="json_object('type','command','command','$cmd_lit')"
  entry_sql="json_object('matcher','','hooks',json_array($hook_obj))"
  tmp=$(mktemp "${TMPDIR:-/tmp}/agmsg-devin.XXXXXX")
  tmp_sql=$(sql_readfile_path "$tmp")
  wrote=$(agmsg_sqlite_mem "
    WITH base AS (
      SELECT CASE WHEN json_extract(readfile('$sql_path'), '\$.$event') IS NULL
                  THEN json_set(readfile('$sql_path'), '\$.$event', json('[]'))
                  ELSE readfile('$sql_path') END AS s
    ),
    out AS (SELECT CASE
      WHEN json_extract(s, '\$.$event') IS NULL THEN
        json_set(s, '\$.$event', json_array($entry_sql))
      ELSE
        json_set(s, '\$.$event',
          (SELECT json_group_array(json(v.value)) FROM (
             SELECT value FROM json_each(json_extract(s, '\$.$event'))
             UNION ALL
             SELECT $entry_sql
           ) v)
        )
    END AS blob FROM base)
    SELECT writefile('$tmp_sql', blob) = length(CAST(blob AS BLOB)) FROM out;
  ") || { rm -f "$tmp"; return 1; }
  [ "$wrote" = "1" ] || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$path"
}

# Devin CLI delivery apply: write hooks.v1.json with top-level event keys.
agmsg_delivery_apply() {
  local type="$1" project="$2" mode="$3"
  local hooks_file
  hooks_file=$(resolve_hooks_file "$type" "$project")
  mkdir -p "$(dirname "$hooks_file")"

  local tmp_state
  tmp_state=$(mktemp "${TMPDIR:-/tmp}/agmsg-devin-state.XXXXXX")
  if [ -f "$hooks_file" ]; then
    cp "$hooks_file" "$tmp_state"
  else
    printf '{}' > "$tmp_state"
  fi

  _devin_strip_event "$tmp_state" "Stop"
  _devin_strip_event "$tmp_state" "SessionStart"
  _devin_strip_event "$tmp_state" "SessionEnd"

  case "$mode" in
    turn)
      local cmd="'$SKILL_DIR/scripts/check-inbox.sh' '$type' '$project'"
      _devin_add_event "$tmp_state" "Stop" "$cmd"
      ;;
    monitor|both)
      echo "Devin CLI does not support monitor/both delivery." >&2
      rm -f "$tmp_state"
      return 1
      ;;
    off)
      : # already stripped
      ;;
  esac

  mv "$tmp_state" "$hooks_file"
}

# Devin CLI delivery status: read top-level event keys.
agmsg_delivery_status() {
  local type="$1" project="$2"
  local hf
  hf=$(resolve_hooks_file "$type" "$project")
  local has_st=0
  if [ -f "$hf" ]; then
    local sql_hf
    sql_hf=$(sql_readfile_path "$hf")
    has_st=$(agmsg_sqlite_mem "
      SELECT EXISTS(
        SELECT 1 FROM json_each(json_extract(readfile('$sql_hf'), '\$.Stop')) AS s,
          json_each(json_extract(s.value, '\$.hooks')) AS h
        WHERE instr(json_extract(h.value, '\$.command'), '$SKILL_NAME') > 0
      );" 2>/dev/null || echo 0)
  fi
  local mode="off"
  if [ "$has_st" = "1" ]; then mode="turn"; fi
  echo "mode: $mode"

  if [ -f "$hf" ]; then
    local sql_hf count
    sql_hf=$(sql_readfile_path "$hf")
    count=$(agmsg_sqlite_mem "SELECT json_array_length(json_extract(readfile('$sql_hf'), '\$.Stop'));" 2>/dev/null || echo 0)
    case "$count" in ''|*[!0-9]*) count=0 ;; esac
    echo "settings hooks file: $hf"
    echo "  Stop entries: $count"
  fi
}

# No special enable side effects; monitor is rejected by delivery.sh's gate.
agmsg_delivery_on_enable() { :; }
