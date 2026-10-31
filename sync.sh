#!/usr/bin/env bash
# Selective dotfile sync and two-level undo. Requires Bash 4.4+, GNU coreutils,
# and flock. Backup manifests are NUL-delimited data, never sourced as shell code.
set -Eeuo pipefail
shopt -s dotglob nullglob

SYSTEM_ENTRY=config-out-dot/pacman.conf
SYSTEM_CONFIG=/etc/pacman.conf

usage() {
    cat <<'EOF'
Usage: sync.sh {to-home|to-repo} [OPTIONS]
       sync.sh --revert [--dry-run]

  --only PATH       Sync one repo-relative file/directory (repeatable)
  --exclude GLOB    Exclude a repo-relative path or quoted glob (repeatable)
  --dry-run         Preview without changing configs or undo history
  --revert          Undo the latest sync; repeat for the preceding sync
  -h, --help        Show this help

Examples:
  ./sync.sh to-home --only config-in-dot/kitty
  ./sync.sh to-repo --exclude 'config-in-dot/hypr/*.log'
  ./sync.sh to-home --only config-out-dot/pacman.conf
  ./sync.sh --revert

Destination-only files are kept. pacman.conf maps to /etc/pacman.conf and
requires explicit --only selection. Backups are stored in .backup/.
EOF
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

normalize() {
    REPLY=$1
    while [[ $REPLY == ./* ]]; do REPLY=${REPLY#./}; done
    while [[ $REPLY == */ ]]; do REPLY=${REPLY%/}; done
    case /$REPLY/ in
        *'/../'*|*'/./'*|*'//'*) die "Use a repo-relative path without empty, '.' or '..' components: $1" ;;
    esac
    case $REPLY in
        config-in-dot|config-in-dot/*|config-out-dot|config-out-dot/*) ;;
        *) die "Path must start with config-in-dot/ or config-out-dot/: $1" ;;
    esac
}

# STATE describes content and mode, not timestamps. Hash link targets without
# following them; hashing stdin also handles filenames containing newlines.
state() {
    local path=$1 hash mode
    if [[ -L $path ]]; then
        hash=$(readlink -z -- "$path" | sha256sum) || die "Cannot read link: $path"
        STATE=l:${hash%% *}
    elif [[ -d $path ]]; then
        mode=$(stat -c '%a' -- "$path") || die "Cannot stat: $path"
        STATE=d:$mode
    elif [[ -f $path ]]; then
        mode=$(stat -c '%a' -- "$path") || die "Cannot stat: $path"
        hash=$(sha256sum < "$path") || die "Cannot read: $path"
        STATE=f:$mode:${hash%% *}
    elif [[ -e $path ]]; then
        die "Unsupported file type: $path"
    else
        STATE=-
    fi
}

safe_parents() {
    local parent=${1%/*}
    while [[ -n $parent ]]; do
        [[ ! -L $parent ]] || die "Refusing to use a symlink directory: $parent"
        [[ $parent != / ]] || break
        parent=${parent%/*}
    done
}

excluded() {
    local relative=$1 pattern prefix
    for pattern in config-in-dot/hypr/tmp config-in-dot/hypr/hyprlock-bkg "${excludes[@]}"; do
        prefix=$relative
        while :; do
            # Deliberately leave the RHS unquoted: it is a Bash glob pattern.
            [[ $prefix != $pattern ]] || return 0
            [[ $prefix == */* ]] || break
            prefix=${prefix%/*}
        done
    done
    return 1
}

live_path() {
    case $1 in
        "$SYSTEM_ENTRY") REPLY=$SYSTEM_CONFIG ;;
        config-in-dot/*) REPLY=$home/.config/${1#*/} ;;
        config-out-dot/*) REPLY=$home/${1#*/} ;;
    esac
}

add_parents() {
    local parent=${1%/*}
    [[ ! ${planned[$parent]+yes} ]] || return 0
    state "$parent"
    if [[ $STATE != - ]]; then
        [[ $STATE == d:* ]] || die "Parent is not a directory: $parent"
        return 0
    fi
    add_parents "$parent"
    planned["$parent"]=1
    paths+=("$parent"); sources+=(""); before+=(-); after+=(d:755)
}

record_change() {
    local destination=$1 source=$2 old=$3 new=$4
    add_parents "$destination"
    planned["$destination"]=1
    paths+=("$destination"); sources+=("$source"); before+=("$old"); after+=("$new")
}

visit() {
    local relative=$1 source destination old new child
    [[ ! ${visited[$relative]+yes} ]] || return 0
    visited["$relative"]=1
    if excluded "$relative"; then return 0; fi
    if [[ $relative == "$SYSTEM_ENTRY" && $explicit_system == false ]]; then return 0; fi
    live_path "$relative"
    if [[ $direction == to-home ]]; then
        source=$repo/$relative; destination=$REPLY
    else
        source=$REPLY; destination=$repo/$relative
    fi
    safe_parents "$source"; safe_parents "$destination"
    state "$source"; new=$STATE
    if [[ $new == - ]]; then
        ((${#only[@]} == 0)) || die "Source does not exist: $source"
        printf 'Skip missing source: %s\n' "$source"
        return 0
    fi
    state "$destination"; old=$STATE
    [[ $old == - || ${old%%:*} == "${new%%:*}" ]] || die "File type conflict: $destination"
    if [[ $relative == "$SYSTEM_ENTRY" ]]; then
        [[ $new == f:* ]] || die 'pacman.conf must be a regular file'
    fi
    if [[ $new == d:* ]]; then
        [[ -r $source && -x $source ]] || die "Cannot list directory: $source"
        if [[ $old == - ]]; then record_change "$destination" "$source" "$old" "$new"; fi
        for child in "$source"/*; do visit "$relative/${child##*/}"; done
    elif [[ $old != "$new" ]]; then
        record_change "$destination" "$source" "$old" "$new"
    fi
}

plan_sync() {
    local group entry selection root managed
    local -a roots=() selections=()
    for group in config-in-dot config-out-dot; do
        [[ -d $repo/$group && ! -L $repo/$group ]] || die "Missing repo directory: $group"
        for entry in "$repo/$group"/*; do roots+=("$group/${entry##*/}"); done
    done
    for selection in "${only[@]}"; do
        managed=false
        for root in "${roots[@]}"; do
            if [[ $selection == "$root" || $selection == "$root/"* || $root == "$selection/"* ]]; then
                managed=true; break
            fi
        done
        [[ $managed == true ]] || die "Not a managed repo entry: $selection"
    done
    if ((${#only[@]})); then selections=("${only[@]}"); else selections=("${roots[@]}"); fi
    for selection in "${selections[@]}"; do
        if [[ $selection == config-in-dot || $selection == config-out-dot ]]; then
            for root in "${roots[@]}"; do
                if [[ $root == "$selection/"* ]]; then visit "$root"; fi
            done
        else
            visit "$selection"
        fi
    done
}

lock_backups() {
    [[ ! -L $backup ]] || die '.backup must not be a symlink'
    mkdir -p -m 700 -- "$backup"
    chmod 700 -- "$backup"
    [[ ! -L $backup/lock ]] || die 'Backup lock must not be a symlink'
    exec {lock_fd}>"$backup/lock"
    flock -x "$lock_fd"
    if [[ -e $backup/history.json || -e $backup/pending.json ]]; then
        die 'Old Python-format backups found. Move .backup aside before using the shell script; do not discard backups you still need.'
    fi
}

valid_id() { [[ $1 =~ ^op-[[:alnum:]]+$ ]] || die 'Invalid backup identifier'; }

load_history() {
    history=()
    if [[ -f $backup/history ]]; then mapfile -t history < "$backup/history"; fi
    local id
    for id in "${history[@]}"; do valid_id "$id"; done
}

save_history() {
    : > "$backup/history.tmp"
    if ((${#history[@]})); then printf '%s\n' "${history[@]}" > "$backup/history.tmp"; fi
    mv -fT -- "$backup/history.tmp" "$backup/history"
}

save_pending() {
    printf '%s\n%s\n' "${operation##*/}" "$applied" > "$backup/pending.tmp"
    mv -fT -- "$backup/pending.tmp" "$backup/pending"
}

authorize() {
    local i
    privileged=false
    for ((i=0; i<applied; i++)); do
        if [[ ${paths[i]} == "$SYSTEM_CONFIG" && ! -w ${SYSTEM_CONFIG%/*} ]]; then
            command -v sudo >/dev/null || die 'sudo is required to write the system config'
            printf 'Administrator permission required to write %s.\n' "$SYSTEM_CONFIG"
            sudo -v
            privileged=true
            break
        fi
    done
}

# All recursive deletion below is limited to this script's own backup folders.
# Destination directories are removed only with rmdir, never rm -r.
remove_operation() {
    local id=${1##*/}
    valid_id "$id"
    [[ $1 == "$backup/$id" ]] || die 'Invalid backup location'
    rm -rf -- "$1"
}

snapshot() {
    local source=$1 destination=$2 expected=$3
    cp -P --preserve=mode,timestamps -- "$source" "$destination"
    state "$destination"
    [[ $STATE == "$expected" ]] || die "File changed while preparing backup: $source"
}

prepare_operation() {
    local i
    operation=$(mktemp -d "$backup/op-XXXXXXXXXX")
    mkdir -- "$operation/before" "$operation/after"
    : > "$operation/manifest"
    for ((i=0; i<${#paths[@]}; i++)); do
        if [[ ${before[i]} == f:* || ${before[i]} == l:* ]]; then
            snapshot "${paths[i]}" "$operation/before/$i" "${before[i]}"
        fi
        if [[ ${after[i]} == f:* || ${after[i]} == l:* ]]; then
            snapshot "${sources[i]}" "$operation/after/$i" "${after[i]}"
        fi
        printf '%s\0%s\0%s\0' "${paths[i]}" "${before[i]}" "${after[i]}" >> "$operation/manifest"
    done
}

write_item() {
    local path=$1 desired=$2 blob=$3 temporary mode
    safe_parents "$path"
    if [[ $privileged == true && $path == "$SYSTEM_CONFIG" ]]; then
        if [[ $desired == - ]]; then
            sudo rm -f -- "$path" || return
        else
            mode=${desired#f:}; mode=${mode%%:*}
            sudo install -m "$mode" -- "$blob" "$path" || return
        fi
    elif [[ $desired == - ]]; then
        if [[ -d $path && ! -L $path ]]; then rmdir -- "$path" || return
        else rm -f -- "$path" || return; fi
    elif [[ $desired == d:* ]]; then
        # Leave new directories writable while their children are copied.
        mode=${desired#d:}
        mkdir -m "$(printf '%o' "$((8#$mode | 0700))")" -- "$path" || return
    else
        temporary=$(mktemp "${path%/*}/.dots-sync-XXXXXXXXXX") || return
        if ! cp -P --preserve=mode,timestamps --remove-destination -- "$blob" "$temporary"; then
            rm -f -- "$temporary"; return 1
        fi
        if ! mv -fT -- "$temporary" "$path"; then
            rm -f -- "$temporary"; return 1
        fi
    fi
}

matches() {
    [[ $1 == "$2" || ( $1 == d:* && $2 == d:* ) ]]
}

check_tree() {
    local directory=$1 child
    [[ -r $directory && -x $directory ]] || die "Cannot check directory for new files: $directory"
    for child in "$directory"/*; do
        [[ ${undo_paths[$child]+yes} ]] || die "Directory contains new files; refusing to remove: $child"
        if [[ -d $child && ! -L $child ]]; then check_tree "$child"; fi
    done
}

verify_undo() {
    local recovering=$1 i
    local -A undo_paths=()
    for ((i=0; i<applied; i++)); do undo_paths["${paths[i]}"]=1; done
    for ((i=0; i<applied; i++)); do
        safe_parents "${paths[i]}"
        state "${paths[i]}"
        if ! { [[ $recovering == true ]] && matches "$STATE" "${before[i]}"; }; then
            matches "$STATE" "${after[i]}" || die "Changed since sync; refusing to overwrite: ${paths[i]}"
        fi
        if [[ ${before[i]} == - && $STATE == d:* ]]; then check_tree "${paths[i]}"; fi
        if [[ ${before[i]} == f:* || ${before[i]} == l:* ]]; then
            state "$operation/before/$i"
            [[ $STATE == "${before[i]}" ]] || die "Backup missing or damaged: $operation/before/$i"
        fi
    done
}

restore_items() {
    local i
    # Only directories created by this operation may need temporary write access.
    for ((i=0; i<applied; i++)); do
        if [[ ${after[i]} == d:* && -d ${paths[i]} && ! -L ${paths[i]} ]]; then
            chmod u+rwx -- "${paths[i]}" || return
        fi
    done
    for ((i=applied-1; i>=0; i--)); do
        state "${paths[i]}"
        if matches "$STATE" "${before[i]}"; then continue; fi
        write_item "${paths[i]}" "${before[i]}" "$operation/before/$i" || return
    done
}

on_exit() {
    local status=$?
    trap - EXIT INT TERM
    if ((status != 0)) && [[ $active == true && $reverting == false ]]; then
        printf 'Sync failed; attempting to restore the previous state.\n' >&2
        if (trap - EXIT; verify_undo true; restore_items || exit 1); then
            rm -f -- "$backup/pending"
            remove_operation "$operation"
        else
            printf 'Recovery is incomplete. Backups retained; run ./sync.sh --revert.\n' >&2
        fi
    elif ((status != 0)) && [[ -n $operation && $active == false && $committed == false && $reverting == false ]]; then
        remove_operation "$operation"
    fi
    exit "$status"
}

sync_configs() {
    local i old mode
    if [[ $dry_run == false ]]; then
        lock_backups
        [[ ! -e $backup/pending ]] || die 'An interrupted operation needs recovery. Run ./sync.sh --revert.'
    fi
    plan_sync
    if [[ $dry_run == true ]]; then
        for old in "${paths[@]}"; do printf 'Would update: %s\n' "$old"; done
        printf '%s change(s); no files written.\n' "${#paths[@]}"
        return
    fi
    if ((${#paths[@]} == 0)); then printf 'Already up to date; no backup created.\n'; return; fi
    load_history
    applied=${#paths[@]}; authorize; applied=0
    prepare_operation
    active=true; save_pending
    for ((i=0; i<${#paths[@]}; i++)); do
        state "${paths[i]}"
        matches "$STATE" "${before[i]}" || die "Changed while preparing sync: ${paths[i]}"
        applied=$((i+1)); save_pending
        write_item "${paths[i]}" "${after[i]}" "$operation/after/$i"
        printf 'Updated: %s\n' "${paths[i]}"
    done
    for ((i=applied-1; i>=0; i--)); do
        if [[ ${after[i]} == d:* ]]; then
            mode=${after[i]#d:}; chmod "$mode" -- "${paths[i]}"
        fi
    done
    local -a expired=()
    history+=("${operation##*/}")
    while ((${#history[@]} > 2)); do expired+=("${history[0]}"); history=("${history[@]:1}"); done
    # From here on pending is the recovery record, even if publishing history
    # fails. Do not delete this operation or roll it back during commit.
    committed=true; active=false
    save_history
    rm -- "$backup/pending"
    for old in "${expired[@]}"; do remove_operation "$backup/$old"; done
    printf 'Sync complete. %s undo level(s) available.\n' "${#history[@]}"
}

revert_sync() {
    local id i recovering=false
    local -a fields=() pending=() remaining=()
    [[ -d $backup && ! -L $backup ]] || die 'No sync to revert.'
    lock_backups; load_history
    if [[ -f $backup/pending ]]; then
        mapfile -t pending < "$backup/pending"
        ((${#pending[@]} == 2)) || die 'Invalid pending operation record'
        id=${pending[0]}; applied=${pending[1]}; recovering=true
        [[ $applied =~ ^[0-9]+$ ]] || die 'Invalid recovery progress'
    else
        ((${#history[@]})) || die 'No sync to revert.'
        id=${history[${#history[@]}-1]}
    fi
    valid_id "$id"; operation=$backup/$id
    [[ -f $operation/manifest && ! -L $operation ]] || die 'Backup manifest is missing'
    mapfile -d '' -t fields < "$operation/manifest"
    ((${#fields[@]} % 3 == 0)) || die 'Invalid backup manifest'
    for ((i=0; i<${#fields[@]}; i+=3)); do
        [[ ${fields[i]} == /* ]] || die 'Backup destination must be absolute'
        paths+=("${fields[i]}"); before+=("${fields[i+1]}"); after+=("${fields[i+2]}")
    done
    if [[ $recovering == false ]]; then applied=${#paths[@]}; fi
    ((applied <= ${#paths[@]})) || die 'Invalid recovery progress'
    verify_undo "$recovering"
    for ((i=applied-1; i>=0; i--)); do
        if [[ $dry_run == true ]]; then printf 'Would restore: %s\n' "${paths[i]}"
        else printf 'Restore: %s\n' "${paths[i]}"; fi
    done
    if [[ $dry_run == true ]]; then return; fi
    authorize
    save_pending; active=true
    restore_items
    for id in "${history[@]}"; do
        if [[ $id != "${operation##*/}" ]]; then remaining+=("$id"); fi
    done
    history=("${remaining[@]}")
    save_history
    rm -- "$backup/pending"; active=false
    remove_operation "$operation"
    printf 'Reverted. %s undo level(s) remaining.\n' "${#history[@]}"
}

main() {
    local command
    repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
    home=$(cd -- "${HOME:?HOME must be set}" && pwd -P)
    backup=$repo/.backup
    direction= dry_run=false reverting=false explicit_system=false privileged=false
    active=false committed=false operation= applied=0
    declare -ga only=() excludes=() paths=() sources=() before=() after=() history=()
    declare -gA visited=() planned=()
    while (($#)); do
        case $1 in
            to-home|to-repo)
                [[ -z $direction ]] || die 'Specify only one direction'
                direction=$1 ;;
            --only|--exclude)
                command=$1; (($# >= 2)) || die "$1 requires a path"
                normalize "$2"
                if [[ $command == --only ]]; then only+=("$REPLY"); else excludes+=("$REPLY"); fi
                shift ;;
            --only=*) normalize "${1#*=}"; only+=("$REPLY") ;;
            --exclude=*) normalize "${1#*=}"; excludes+=("$REPLY") ;;
            --dry-run) dry_run=true ;;
            --revert) reverting=true ;;
            -h|--help) usage; return ;;
            *) die "Unknown argument: $1 (see --help)" ;;
        esac
        shift
    done
    if [[ $reverting == true ]]; then
        [[ -z $direction && ${#only[@]} == 0 && ${#excludes[@]} == 0 ]] || die '--revert cannot be combined with direction, --only, or --exclude'
    else
        [[ -n $direction ]] || die 'Choose to-home, to-repo, or --revert (see --help)'
    fi
    for command in cp mv rm mkdir rmdir chmod stat sha256sum readlink mktemp flock; do
        command -v "$command" >/dev/null || die "Required command not found: $command"
    done
    for command in "${only[@]}"; do
        if [[ $command == "$SYSTEM_ENTRY" ]]; then explicit_system=true; fi
    done
    umask 077
    trap on_exit EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    if [[ $reverting == true ]]; then revert_sync; else sync_configs; fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
