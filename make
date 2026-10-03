#!/usr/bin/env bash
# Linux tasks. All generated data stays inside this project.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TASK="${1:-help}"
if (($#)); then shift; fi

help() {
    cat <<'HELP'
Chromaton (Linux): ./make <task> [args]
  play [args]                 Start the game
  level <id> [args]           Open a level (e.g. wash_out)
  unlock [args]              Open every level
  editor                     Open the Godot editor
  godot                      Show the engine path and version
  import                     Import assets and compile the project
  check                      Compile every script
  test [suite ...]           Run existing test suites
  smoke [game args]          Run the game headlessly for 90 frames
  shot <level> <png> [args]   Render a screenshot; level may be levels or book
  export-pack                Build builds/linux/Chromaton.pck
  export                     Build builds/linux/Chromaton.x86_64 (needs templates)
  play-export [args]          Start the exported Linux build
  solve | cards | algebra    Run design tools (rewrite project files)

Uses GODOT if set, then the project-local portable engine, then godot4/godot
on PATH. Godot 4.7 or newer is required. Data, settings, caches and temporary
files are kept in .linux-user/; the portable editor also uses editor_data/
beside its executable. Screenshot paths must be inside the project.
Uses OpenGL ES and software rendering to avoid driver startup errors on this
machine. Set CHROMATON_SOFTWARE_RENDERING=0 to try hardware acceleration.
HELP
}
if [[ "$TASK" == help ]]; then help; exit 0; fi

DATA_PROFILE=data
case "$TASK" in test | check | smoke | shot) DATA_PROFILE=test-data ;; esac
# Screenshot completion emits progress-save signals. Keep those saves separate
# from real play, including when screenshot args are passed to play-export.
for argument in "$@"; do
    if [[ "$argument" == --screenshot=* ]]; then DATA_PROFILE=test-data; fi
done
export XDG_DATA_HOME="$ROOT/.linux-user/$DATA_PROFILE"
export XDG_CONFIG_HOME="$ROOT/.linux-user/config"
export XDG_CACHE_HOME="$ROOT/.linux-user/cache"
export XDG_STATE_HOME="$ROOT/.linux-user/state"
export TMPDIR="$ROOT/.linux-user/tmp"
export MESA_SHADER_CACHE_DIR="$XDG_CACHE_HOME/mesa"
export __GL_SHADER_DISK_CACHE_PATH="$XDG_CACHE_HOME/nvidia"
if [[ "${CHROMATON_SOFTWARE_RENDERING:-1}" == 1 ]]; then
    export LIBGL_ALWAYS_SOFTWARE=1
fi
RENDER_ARGS=(--rendering-driver opengl3_es)
mkdir -p -- "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$TMPDIR"
cd -- "$ROOT"

if [[ "$TASK" == play-export ]]; then
    build="$ROOT/builds/linux/Chromaton.x86_64"
    if [[ ! -x "$build" ]]; then echo 'Run ./make export first.' >&2; exit 1; fi
    exec "$build" "${RENDER_ARGS[@]}" -- "$@"
fi

ENGINE=""
if [[ -n "${GODOT:-}" ]]; then
    ENGINE="$(command -v -- "$GODOT" || true)"
    if [[ -z "$ENGINE" || ! -x "$ENGINE" ]]; then
        printf 'GODOT is not an executable: %s\n' "$GODOT" >&2
        exit 1
    fi
else
    for candidate in "$ROOT"/.linux-tools/godot/Godot*_linux.*; do
        if [[ -f "$candidate" && -x "$candidate" ]]; then ENGINE="$candidate"; break; fi
    done
    if [[ -z "$ENGINE" ]]; then
        ENGINE="$(command -v godot4 || command -v godot || true)"
    fi
fi
if [[ -z "$ENGINE" ]]; then
    echo 'Godot not found. See TESTING.md for portable Linux setup, or set GODOT.' >&2
    exit 1
fi
VERSION="$("$ENGINE" --version)"
if [[ ! "$VERSION" =~ ^4\.([0-9]+)\. ]] || (( ${BASH_REMATCH[1]:-0} < 7 )); then
    printf 'Godot 4.7 or newer in the 4.x series is required; found %s\n' "$VERSION" >&2
    exit 1
fi

# Godot may exit successfully despite script errors. Check the output as well.
run_checked() {
    local log code=0
    log="$(mktemp "$TMPDIR/chromaton.XXXXXX.log")"
    "$ENGINE" "$@" >"$log" 2>&1 || code=$?
    cat -- "$log"
    if ((code == 0)) && grep -Eq 'SCRIPT ERROR|(^|[[:space:]])ERROR:' "$log"; then code=1; fi
    if ((code == 0)); then rm -- "$log"; else printf 'Failure log: %s\n' "$log" >&2; fi
    return "$code"
}
ensure_imported() {
    if [[ ! -f "$ROOT/.godot/uid_cache.bin" ]] ||
       ! compgen -G "$ROOT/.godot/imported/Fredoka.ttf-*.fontdata" >/dev/null ||
       ! compgen -G "$ROOT/.godot/imported/Nunito.ttf-*.fontdata" >/dev/null; then
        run_checked --headless --audio-driver Dummy --path "$ROOT" --import
    fi
}
tool() {
    ensure_imported
    run_checked --headless --audio-driver Dummy --path "$ROOT" --script "res://tools/$1.gd"
}

case "$TASK" in
    godot) printf '%s\n%s\n' "$ENGINE" "$VERSION" ;;
    import) run_checked --headless --audio-driver Dummy --path "$ROOT" --import ;;
    play) ensure_imported; exec "$ENGINE" "${RENDER_ARGS[@]}" --path "$ROOT" -- "$@" ;;
    level)
        if (($# < 1)); then echo 'Usage: ./make level <id> [args]' >&2; exit 1; fi
        level="$1"; shift
        if [[ ! -f "$ROOT/levels/$level.json" || "$level" == */* ]]; then
            printf 'Unknown level: %s\n' "$level" >&2; exit 1
        fi
        ensure_imported; exec "$ENGINE" "${RENDER_ARGS[@]}" --path "$ROOT" -- "--level=$level" "$@"
        ;;
    unlock) ensure_imported; exec "$ENGINE" "${RENDER_ARGS[@]}" --path "$ROOT" -- --unlock-all "$@" ;;
    editor) exec "$ENGINE" "${RENDER_ARGS[@]}" --editor --path "$ROOT" ;;
    test)
        ensure_imported
        run_checked --headless --audio-driver Dummy --path "$ROOT" --script res://tests/test_all.gd -- "$@"
        ;;
    check) tool check_scripts ;;
    solve) tool level_solver ;;
    cards) tool make_cards ;;
    algebra) tool algebra_check ;;
    smoke)
        ensure_imported
        run_checked --headless --audio-driver Dummy --path "$ROOT" --quit-after 90 -- "$@"
        ;;
    shot)
        if (($# < 2)); then echo 'Usage: ./make shot <level> <png> [args]' >&2; exit 1; fi
        level="$1"; png="$(realpath -m -- "$2")"; shift 2
        case "$png" in "$ROOT"/*) ;; *) echo 'Screenshot must be inside the project.' >&2; exit 1 ;; esac
        ensure_imported
        run_checked "${RENDER_ARGS[@]}" --audio-driver Dummy --path "$ROOT" -- "--screenshot=$level:$png" "$@"
        ;;
    export-pack | export)
        ensure_imported
        mkdir -p -- "$ROOT/builds/linux"
        if [[ "$TASK" == export-pack ]]; then
            run_checked --headless --audio-driver Dummy --path "$ROOT" --export-pack 'Linux' "$ROOT/builds/linux/Chromaton.pck"
        else
            run_checked --headless --audio-driver Dummy --path "$ROOT" --export-release 'Linux' "$ROOT/builds/linux/Chromaton.x86_64"
        fi
        ;;
    *) printf 'Unknown task: %s\n' "$TASK" >&2; help; exit 1 ;;
esac
