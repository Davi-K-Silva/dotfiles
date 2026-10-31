#!/usr/bin/env bash
# Isolated integration tests; never write installed configs or /etc.
set -Eeuo pipefail

project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
temp_root=${TMPDIR:-/tmp/opencode}
[[ -d $temp_root ]] || temp_root=/tmp
suite=$(mktemp -d "$temp_root/dotfiles-tests-XXXXXXXXXX")
log=$suite/output
trap 'status=$?; if ((status)); then cat -- "$log" >&2; fi; rm -rf -- "$suite"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

setup() {
    repo=$suite/$1/repo
    home=$suite/$1/home
    system=$suite/$1/etc/pacman.conf
    mkdir -p -- "$repo/config-in-dot" "$repo/config-out-dot" "$home" "${system%/*}"
    cp -- "$project/sync.sh" "$repo/sync.sh"
    : > "$log"
}

put() { mkdir -p -- "${1%/*}"; printf '%s' "$2" > "$1"; }
content() { [[ $(cat -- "$1") == "$2" ]] || fail "Unexpected content: $1"; }
absent() { [[ ! -e $1 && ! -L $1 ]] || fail "Should not exist: $1"; }
exists() { [[ -e $1 || -L $1 ]] || fail "Missing: $1"; }

run_sync() {
    # Source only to substitute an isolated pacman.conf path for system tests.
    # Production has no environment override for its system destination.
    {
        HOME=$home bash -c 'source "$1"; SYSTEM_CONFIG=$2; shift 2; main "$@"' \
            bash "$repo/sync.sh" "$system" "$@"
    } >> "$log" 2>&1
}

expect_failure() {
    if run_sync "$@"; then fail "Expected failure: $*"; fi
}

history_count() {
    local -a records=()
    if [[ -f $repo/.backup/history ]]; then mapfile -t records < "$repo/.backup/history"; fi
    [[ ${#records[@]} == "$1" ]] || fail "Expected $1 undo levels, got ${#records[@]}"
}

test_round_trip() {
    put "$repo/config-in-dot/kitty/kitty.conf" repo
    put "$home/.config/kitty/kitty.conf" home
    put "$home/.config/kitty/local.conf" extra
    put "$home/.config/unmanaged/a" unmanaged
    run_sync to-home
    content "$home/.config/kitty/kitty.conf" repo
    content "$home/.config/kitty/local.conf" extra
    put "$home/.config/kitty/kitty.conf" edited
    run_sync to-repo
    content "$repo/config-in-dot/kitty/kitty.conf" edited
    content "$repo/config-in-dot/kitty/local.conf" extra
    absent "$repo/config-in-dot/unmanaged"
    run_sync --revert
    content "$repo/config-in-dot/kitty/kitty.conf" repo
    absent "$repo/config-in-dot/kitty/local.conf"
    expect_failure --revert  # The live edit is not undone by reverting to-repo.
    put "$home/.config/kitty/kitty.conf" repo
    run_sync --revert
    content "$home/.config/kitty/kitty.conf" home
    content "$home/.config/kitty/local.conf" extra
}

test_selections_and_globs() {
    put "$repo/config-in-dot/kitty/a.conf" a
    put "$repo/config-in-dot/kitty/b.log" b
    put "$repo/config-in-dot/kitty/sub/c.log" c
    put "$repo/config-out-dot/.zshrc" z
    run_sync to-home --only config-in-dot/kitty/a.conf --only config-in-dot/kitty/a.conf
    exists "$home/.config/kitty/a.conf"
    absent "$home/.config/kitty/b.log"
    absent "$home/.zshrc"
    run_sync to-home --only=config-in-dot --exclude='config-in-dot/kitty/*.log'
    absent "$home/.config/kitty/b.log"
    absent "$home/.config/kitty/sub/c.log"
    run_sync to-home --exclude config-in-dot/kitty --exclude config-out-dot/.zshrc
    absent "$home/.zshrc"
}

test_always_excluded() {
    put "$repo/config-in-dot/hypr/tmp/a" no
    put "$repo/config-in-dot/hypr/hyprlock-bkg/a" no
    put "$repo/config-in-dot/hypr/hyprland.lua" yes
    run_sync to-home
    absent "$home/.config/hypr/tmp"
    absent "$home/.config/hypr/hyprlock-bkg"
    content "$home/.config/hypr/hyprland.lua" yes
    run_sync to-home --only config-in-dot/hypr/tmp/a
    absent "$home/.config/hypr/tmp"
}

test_two_levels_and_noop() {
    put "$home/.zshrc" zero
    local value
    for value in one two three; do
        put "$repo/config-out-dot/.zshrc" "$value"
        run_sync to-home
    done
    run_sync to-home
    history_count 2
    local -a operations=("$repo"/.backup/op-*)
    [[ ${#operations[@]} == 2 ]] || fail 'Old backup not pruned'
    run_sync --revert; content "$home/.zshrc" two
    run_sync --revert; content "$home/.zshrc" one
    history_count 0
    expect_failure --revert
}

test_modes_links_and_new_directories() {
    put "$repo/config-in-dot/app/nested/run" hello
    chmod 751 "$repo/config-in-dot/app/nested/run"
    ln -s run "$repo/config-in-dot/app/nested/link"
    ln -s missing "$repo/config-in-dot/app/nested/dangling"
    chmod 555 "$repo/config-in-dot/app/nested"
    run_sync to-home
    [[ $(stat -c %a "$home/.config/app/nested/run") == 751 ]] || fail 'File mode not copied'
    [[ $(stat -c %a "$home/.config/app/nested") == 555 ]] || fail 'Directory mode not copied'
    [[ $(readlink "$home/.config/app/nested/link") == run ]] || fail 'Link not copied'
    [[ -L $home/.config/app/nested/dangling ]] || fail 'Dangling link not copied'
    run_sync --revert
    absent "$home/.config"
    chmod 755 "$repo/config-in-dot/app/nested"
}

test_existing_links_and_modes_restored() {
    put "$repo/config-out-dot/.zshrc" new
    put "$home/.zshrc" old
    chmod 640 "$home/.zshrc"
    ln -s new-target "$repo/config-out-dot/.link"
    ln -s old-target "$home/.link"
    run_sync to-home
    run_sync --revert
    content "$home/.zshrc" old
    [[ $(stat -c %a "$home/.zshrc") == 640 ]] || fail 'Original mode not restored'
    [[ $(readlink "$home/.link") == old-target ]] || fail 'Original link not restored'
}

test_subsequent_edits_protected() {
    put "$repo/config-out-dot/.zshrc" new
    run_sync to-home
    put "$home/.zshrc" work
    expect_failure --revert
    content "$home/.zshrc" work
    history_count 1
    put "$home/.zshrc" new
    run_sync --revert
    absent "$home/.zshrc"
}

test_new_files_protected() {
    put "$repo/config-in-dot/app/a" repo
    run_sync to-home
    put "$home/.config/app/local" work
    expect_failure --revert
    content "$home/.config/app/local" work
    exists "$home/.config/app/a"
    history_count 1
}

test_dry_runs() {
    put "$repo/config-out-dot/.zshrc" repo
    run_sync to-home --dry-run
    absent "$home/.zshrc"
    absent "$repo/.backup"
    run_sync to-home
    run_sync --revert --dry-run
    exists "$home/.zshrc"
    history_count 1
    [[ $(stat -c %a "$repo/.backup") == 700 ]] || fail 'Backups are not private'
}

test_system_config() {
    put "$repo/config-out-dot/pacman.conf" repo
    put "$system" system
    run_sync to-home --only config-out-dot
    content "$system" system
    run_sync to-home --only config-out-dot/pacman.conf
    content "$system" repo
    run_sync --revert
    content "$system" system
    run_sync to-repo
    content "$repo/config-out-dot/pacman.conf" repo
    run_sync to-repo --only config-out-dot/pacman.conf
    content "$repo/config-out-dot/pacman.conf" system
    run_sync --revert
    content "$repo/config-out-dot/pacman.conf" repo
}

test_conflicts_and_paths() {
    put "$repo/config-in-dot/app/a" repo
    mkdir "$home/outside"
    ln -s outside "$home/.config"
    expect_failure to-home
    absent "$home/outside/app"
    rm "$home/.config"
    put "$home/.config/app" conflict
    expect_failure to-home
    content "$home/.config/app" conflict
    expect_failure to-home --only ../secret
    expect_failure to-home --only config-in-dot/../secret
    expect_failure to-home --only /etc/passwd
    expect_failure to-home --only README.md
    expect_failure to-home --only config-in-dot/unmanaged
    expect_failure to-home --only
    expect_failure --revert to-home
}

test_missing_sources() {
    put "$repo/config-out-dot/.zshrc" repo
    run_sync to-repo
    content "$repo/config-out-dot/.zshrc" repo
    history_count 0
    expect_failure to-repo --only config-out-dot/.zshrc
}

test_unusual_names() {
    local name=$'space dir/line\nfile' target=$'target\n'
    put "$repo/config-in-dot/$name" unusual
    ln -s "$target" "$repo/config-out-dot/.link"
    run_sync to-home
    content "$home/.config/$name" unusual
    cmp <(readlink -z "$repo/config-out-dot/.link") <(readlink -z "$home/.link")
    run_sync --revert
    absent "$home/.config"
    absent "$home/.link"
}

install_mv_hook() {
    mkdir "$repo/bin"
    export REAL_MV FAIL_DEST FAIL_MARKER HOOK_MODE
    REAL_MV=$(command -v mv)
    FAIL_DEST=$home/.zshrc
    FAIL_MARKER=$repo/hook-used
    cat > "$repo/bin/mv" <<'EOF'
#!/usr/bin/env bash
if [[ ${!#} == "$FAIL_DEST" && ! -e $FAIL_MARKER ]]; then
    : > "$FAIL_MARKER"
    if [[ $HOOK_MODE == fail ]]; then exit 1; fi
    "$REAL_MV" "$@" || exit
    kill -KILL "$PPID"
    exit 0
fi
exec "$REAL_MV" "$@"
EOF
    chmod +x "$repo/bin/mv"
}

test_failed_sync_rolls_back() {
    put "$repo/config-out-dot/.bashrc" 'new bash'
    put "$repo/config-out-dot/.zshrc" 'new zsh'
    put "$home/.bashrc" 'old bash'
    put "$home/.zshrc" 'old zsh'
    install_mv_hook
    HOOK_MODE=fail
    PATH=$repo/bin:$PATH expect_failure to-home
    content "$home/.bashrc" 'old bash'
    content "$home/.zshrc" 'old zsh'
    absent "$repo/.backup/pending"
    history_count 0
}

test_interrupted_sync_recovers() {
    put "$repo/config-out-dot/.zshrc" new
    put "$home/.zshrc" old
    install_mv_hook
    HOOK_MODE=kill
    PATH=$repo/bin:$PATH expect_failure to-home
    content "$home/.zshrc" new
    expect_failure to-home
    run_sync --revert
    content "$home/.zshrc" old
    absent "$repo/.backup/pending"
}

test_interrupted_revert_resumes() {
    put "$repo/config-out-dot/.bashrc" 'new bash'
    put "$repo/config-out-dot/.zshrc" 'new zsh'
    put "$home/.bashrc" 'old bash'
    put "$home/.zshrc" 'old zsh'
    run_sync to-home
    install_mv_hook
    HOOK_MODE=kill
    PATH=$repo/bin:$PATH expect_failure --revert
    content "$home/.zshrc" 'old zsh'
    run_sync --revert
    content "$home/.bashrc" 'old bash'
    content "$home/.zshrc" 'old zsh'
    history_count 0
}

test_cli_from_other_directory() {
    put "$repo/config-out-dot/.zshrc" repo
    (cd "$suite"; HOME=$home bash "$repo/sync.sh" to-home --only config-out-dot/.zshrc) >> "$log" 2>&1
    content "$home/.zshrc" repo
}

test_old_backups_not_discarded() {
    put "$repo/config-out-dot/.zshrc" repo
    put "$repo/.backup/history.json" '[]'
    expect_failure to-home
    content "$repo/.backup/history.json" '[]'
    absent "$home/.zshrc"
}

tests=(
    test_round_trip test_selections_and_globs test_always_excluded
    test_two_levels_and_noop test_modes_links_and_new_directories
    test_existing_links_and_modes_restored test_subsequent_edits_protected
    test_new_files_protected test_dry_runs test_system_config
    test_conflicts_and_paths test_missing_sources test_unusual_names
    test_failed_sync_rolls_back test_interrupted_sync_recovers
    test_interrupted_revert_resumes test_cli_from_other_directory
    test_old_backups_not_discarded
)
for test in "${tests[@]}"; do
    setup "$test"
    "$test"
    printf 'PASS %s\n' "$test"
done
printf '\nAll %s tests passed.\n' "${#tests[@]}"
