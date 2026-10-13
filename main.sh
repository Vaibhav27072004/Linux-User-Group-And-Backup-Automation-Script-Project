#!/bin/bash
#
# User Management & Backup Automation in Linux
# Menu-driven wrapper around common user, group and backup administration tasks.
#
# set -e is deliberately NOT used: this is an interactive menu loop, and a single
# failed command should report an error and return to the menu, not kill the script.
set -uo pipefail

# -------------------- Paths --------------------
# Anchor all state to the script's own directory so logs and backups do not
# scatter into whatever directory the script happened to be invoked from.
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/logs"
BACKUP_DIR="$SCRIPT_DIR/backup"
LOG_FILE="$LOG_DIR/activity.log"

REAL_USER="$(id -un)"

if ! mkdir -p "$LOG_DIR" "$BACKUP_DIR"; then
    echo "FATAL: cannot create '$LOG_DIR' and '$BACKUP_DIR'." >&2
    exit 1
fi

trap 'echo; echo "Interrupted."; exit 130' INT

# -------------------- Helpers --------------------

# Run a command as root, via sudo only when we are not already root.
priv() {
    if (( EUID == 0 )); then
        "$@"
    else
        sudo "$@"
    fi
}

log_action() {
    if ! printf '%s : [%s] %s\n' "$(date +"%F %T")" "$REAL_USER" "$1" >> "$LOG_FILE"; then
        echo "WARNING: could not write to log file '$LOG_FILE'." >&2
    fi
}

# run_action <success message> <log description> <command> [args...]
# Reports and logs the real outcome of the command instead of assuming success.
run_action() {
    local success_msg="$1" log_msg="$2"
    shift 2
    local rc=0 shown
    "$@" || rc=$?
    if (( rc == 0 )); then
        echo "$success_msg"
        log_action "OK: $log_msg"
    else
        # Show the real command, not the internal priv() wrapper around it.
        shown="$*"
        shown="${shown#priv }"
        echo "ERROR: '$shown' failed with exit status $rc." >&2
        echo "       No change was made (or the change is incomplete)." >&2
        log_action "FAILED (exit $rc): $log_msg"
    fi
    return "$rc"
}

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# ask <varname> <prompt> -- reads a trimmed, non-empty value; returns 1 otherwise.
ask() {
    local __var="$1" __prompt="$2" __val
    if ! read -r -p "$__prompt" __val; then
        echo >&2
        return 1
    fi
    __val="$(trim "$__val")"
    if [[ -z "$__val" ]]; then
        echo "Input cannot be empty." >&2
        return 1
    fi
    printf -v "$__var" '%s' "$__val"
}

# Names accepted for NEW users and groups, matching the usual Linux NAME_REGEX.
valid_new_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z_][a-z0-9_-]{0,31}\$?$ ]]; then
        echo "Invalid name '$name'." >&2
        echo "Use 1-32 characters: start with a lowercase letter or underscore," >&2
        echo "then lowercase letters, digits, underscores or hyphens." >&2
        return 1
    fi
}

# Names used to LOOK UP an existing account: id/getent is the real authority,
# so only reject input that cannot be a name at all.
valid_lookup_name() {
    local name="$1"
    if [[ "$name" =~ [[:space:]/] ]]; then
        echo "Invalid name '$name': names cannot contain whitespace or '/'." >&2
        return 1
    fi
    # A leading '-' would be parsed as an option by id/getent/usermod rather than
    # as a name: 'id -u' exits 0, so the script would believe the user exists and
    # then hand '-u' to a privileged command as a flag. Linux names cannot start
    # with '-' anyway, so reject it outright.
    if [[ "$name" == -* ]]; then
        echo "Invalid name '$name': names cannot start with '-'." >&2
        return 1
    fi
}

user_exists()  { id -- "$1" &>/dev/null; }
group_exists() { getent group "$1" &>/dev/null; }

# Canonical physical path of a directory. Every path that gets compared to
# another must go through this, so the same directory always has one spelling
# (readlink -f and cd+pwd can disagree, and a prefix test then silently fails).
canon_dir() {
    local d
    d="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
    printf '%s' "$d"
}

rule() { echo "-------------------------------------------"; }

# -------------------- Add User --------------------
add_user() {
    local username
    ask username "Enter username to add: " || return
    valid_new_name "$username" || return

    if user_exists "$username"; then
        echo "User '$username' already exists!"
        return
    fi

    run_action "User '$username' added successfully." \
               "add user $username" \
               priv useradd -m "$username"
}

# -------------------- Delete User --------------------
delete_user() {
    local username confirm
    ask username "Enter username to delete: " || return
    valid_lookup_name "$username" || return

    if ! user_exists "$username"; then
        echo "User '$username' not found!"
        return
    fi

    echo
    echo "WARNING: this permanently deletes the account '$username' AND its home"
    echo "         directory and mail spool. This cannot be undone."
    if ! read -r -p "Type the username again to confirm: " confirm; then
        echo; return
    fi
    if [[ "$(trim "$confirm")" != "$username" ]]; then
        echo "Names did not match. Operation cancelled."
        return
    fi

    run_action "User '$username' deleted successfully." \
               "delete user $username (with home directory)" \
               priv userdel -r "$username"
}

# ---------------- Modify User's Home Directory ----------------
modify_user() {
    local username new_home
    ask username "Enter username to modify: " || return
    valid_lookup_name "$username" || return

    if ! user_exists "$username"; then
        echo "User '$username' not found!"
        return
    fi

    echo "Current home: $(getent passwd "$username" | cut -d: -f6)"
    ask new_home "Enter new home directory (absolute path): " || return

    if [[ "$new_home" != /* ]]; then
        echo "Home directory must be an absolute path (starting with '/')." >&2
        return
    fi
    if [[ "$new_home" == *".."* ]]; then
        echo "Home directory must not contain '..'." >&2
        return
    fi

    # -m moves the existing contents; without it the user's files are left
    # behind at the old path and the account points at an empty directory.
    run_action "Home directory of '$username' changed to $new_home" \
               "modify user $username (new home: $new_home)" \
               priv usermod -m -d "$new_home" "$username"
}

# -------------------- Create Group --------------------
create_group() {
    local group
    ask group "Enter group name: " || return
    valid_new_name "$group" || return

    if group_exists "$group"; then
        echo "Group '$group' already exists!"
        return
    fi

    run_action "Group '$group' created." \
               "create group $group" \
               priv groupadd "$group"
}

# -------------------- Add User to Group --------------------
add_user_to_group() {
    local username group
    ask username "Enter username: " || return
    valid_lookup_name "$username" || return
    if ! user_exists "$username"; then
        echo "User '$username' not found!"
        return
    fi

    ask group "Enter group name: " || return
    valid_lookup_name "$group" || return
    if ! group_exists "$group"; then
        echo "Group '$group' does not exist!"
        return
    fi

    run_action "User '$username' added to group '$group' successfully." \
               "add user $username to group $group" \
               priv usermod -aG "$group" "$username"
}

# -------------------- Remove User from Group --------------------
remove_user_from_group() {
    local username group
    ask username "Enter username: " || return
    valid_lookup_name "$username" || return
    if ! user_exists "$username"; then
        echo "User '$username' not found!"
        return
    fi

    ask group "Enter group name: " || return
    valid_lookup_name "$group" || return
    if ! group_exists "$group"; then
        echo "Group '$group' does not exist!"
        return
    fi

    run_action "User '$username' removed from group '$group' successfully." \
               "remove user $username from group $group" \
               priv gpasswd -d "$username" "$group"
}

# -------------------- Delete Group --------------------
delete_group() {
    local group confirm
    ask group "Enter group name to delete: " || return
    valid_lookup_name "$group" || return

    if ! group_exists "$group"; then
        echo "Group '$group' not found!"
        return
    fi

    if ! read -r -p "Delete group '$group'? (yes/no): " confirm; then
        echo; return
    fi
    if [[ "$(trim "$confirm")" != "yes" ]]; then
        echo "Operation cancelled."
        return
    fi

    run_action "Group '$group' deleted successfully." \
               "delete group $group" \
               priv groupdel "$group"
}

# -------------------- List Users --------------------
list_users() {
    local uid_min uid_max
    uid_min="$(awk '/^UID_MIN/{print $2; exit}' /etc/login.defs 2>/dev/null)"
    uid_max="$(awk '/^UID_MAX/{print $2; exit}' /etc/login.defs 2>/dev/null)"
    [[ "$uid_min" =~ ^[0-9]+$ ]] || uid_min=1000
    [[ "$uid_max" =~ ^[0-9]+$ ]] || uid_max=60000

    echo
    rule
    echo "Regular Users (UID $uid_min - $uid_max):"
    rule
    awk -F: -v lo="$uid_min" -v hi="$uid_max" \
        '$3 >= lo && $3 <= hi {print "Username: " $1 "\tUID: " $3 "\tHome: " $6}' \
        /etc/passwd
    rule
}

# -------------------- List Groups --------------------
list_groups() {
    echo
    rule
    echo "System Groups:"
    rule
    if command -v column >/dev/null 2>&1; then
        cut -d: -f1 /etc/group | column
    else
        cut -d: -f1 /etc/group
    fi
    rule
}

# -------------------- View User's Groups --------------------
view_user_groups() {
    local username
    ask username "Enter username: " || return
    valid_lookup_name "$username" || return

    if ! user_exists "$username"; then
        echo "User '$username' not found!"
        return
    fi

    rule
    echo "Groups for user '$username':"
    rule
    groups "$username"
    rule
}

# -------------------- View Group Members --------------------
view_group_members() {
    local group
    ask group "Enter group name: " || return
    valid_lookup_name "$group" || return

    if ! group_exists "$group"; then
        echo "Group '$group' not found!"
        return
    fi

    rule
    echo "Members of group '$group':"
    rule
    getent group "$group" | cut -d: -f4
    rule
}

# -------------------- View Logs --------------------
view_logs() {
    local view_choice num_lines
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Log file not found!"
        return
    fi

    rule
    echo "Activity Log ($LOG_FILE):"
    rule
    if ! read -r -p "View (a)ll logs or last (n) lines? [a/n]: " view_choice; then
        echo; return
    fi

    case "$(trim "$view_choice")" in
        a|A) cat "$LOG_FILE" ;;
        n|N)
            ask num_lines "Enter number of lines: " || return
            if [[ ! "$num_lines" =~ ^[0-9]+$ ]] || (( num_lines == 0 )); then
                echo "Please enter a positive whole number." >&2
                return
            fi
            tail -n "$num_lines" "$LOG_FILE"
            ;;
        *) echo "Invalid choice!" ;;
    esac
    rule
}

# -------------------- Clear Logs --------------------
clear_logs() {
    local confirm
    if ! read -r -p "Are you sure you want to clear all logs? (yes/no): " confirm; then
        echo; return
    fi
    if [[ "$(trim "$confirm")" != "yes" ]]; then
        echo "Operation cancelled."
        return
    fi

    if : > "$LOG_FILE"; then
        echo "Logs cleared successfully."
        log_action "OK: clear all logs"
    else
        echo "ERROR: could not clear '$LOG_FILE'." >&2
    fi
}

# -------------------- Backup Directory --------------------
backup_directory() {
    local dir src parent base safe_base stamp archive partial rc=0 n=1 d rel
    local -a excludes=()

    ask dir "Enter directory path to backup: " || return

    if [[ ! -d "$dir" ]]; then
        echo "Directory not found!"
        return
    fi
    if [[ ! -r "$dir" ]]; then
        echo "Directory '$dir' is not readable by $REAL_USER." >&2
        return
    fi

    if ! src="$(canon_dir "$dir")"; then
        echo "ERROR: could not resolve '$dir'." >&2
        return 1
    fi
    if [[ "$src" == "/" ]]; then
        echo "Refusing to back up '/' into a directory inside itself." >&2
        return
    fi

    parent="$(dirname "$src")"
    base="$(basename "$src")"

    # Timestamp is taken per backup. Taken once at script start, every backup in
    # a session shared one filename and silently overwrote the previous archive.
    stamp="$(date +%Y-%m-%d-%H-%M-%S)"
    safe_base="$(printf '%s' "$base" | tr -c 'A-Za-z0-9._-' '_')"
    archive="$BACKUP_DIR/backup-$safe_base-$stamp.tar.gz"

    # Two backups of the same directory inside the same second would otherwise
    # collide, so add a counter rather than overwriting or refusing the request.
    while [[ -e "$archive" ]]; do
        archive="$BACKUP_DIR/backup-$safe_base-$stamp-$n.tar.gz"
        if (( ++n > 1000 )); then
            echo "ERROR: could not find a free filename for this backup." >&2
            return 1
        fi
    done

    # Write to a .part file so a failed run cannot leave a truncated archive
    # sitting in the backup directory looking like a usable backup.
    if [[ "$BACKUP_DIR" == "$src" || "$LOG_DIR" == "$src" ]]; then
        # Creating the part file inside the very directory being archived changes
        # that directory's mtime while tar reads it, so tar reports exit 1 even
        # though the archive is complete. Stage it outside the source instead.
        if ! partial="$(mktemp "${TMPDIR:-/tmp}/backup-$safe_base-XXXXXX.tar.gz.part")"; then
            echo "ERROR: could not create a temporary file for this backup." >&2
            return 1
        fi
    else
        partial="$archive.part"
    fi

    # Archiving with -C keeps member paths relative, so tar no longer has to
    # strip a leading '/' and the archive extracts into the current directory.
    # tar must never read the archive it is writing. If one of our own
    # directories sits inside the source tree, exclude it wholesale; if the
    # source IS one of them, exclude only the part file so the user still gets
    # a backup of everything else in there.
    for d in "$BACKUP_DIR" "$LOG_DIR"; do
        if [[ "$d" == "$src" ]]; then
            excludes+=( --exclude="$base/${partial##*/}" )
        elif [[ "$d/" == "$src/"* ]]; then
            rel="${d#"$src"/}"
            excludes+=( --exclude="$base/$rel" )
        fi
    done

    tar -C "$parent" ${excludes[@]+"${excludes[@]}"} -czf "$partial" "$base" || rc=$?

    # GNU tar: 0 = fine, 1 = some files changed or differed while being read,
    # 2 and above = fatal. Only a fatal error means there is no usable archive;
    # discarding the archive on exit 1 would leave someone backing up a live
    # directory with nothing at all.
    if (( rc >= 2 )); then
        rm -f "$partial"
        echo "ERROR: tar failed with exit status $rc. No backup was created." >&2
        log_action "FAILED (exit $rc): backup $src"
        return "$rc"
    fi

    if ! mv "$partial" "$archive"; then
        rm -f "$partial"
        echo "ERROR: could not finalise '$archive'." >&2
        log_action "FAILED: backup $src (could not finalise archive)"
        return 1
    fi

    echo "Backup created at: $archive"
    echo "Size: $(du -h "$archive" | cut -f1)"

    if (( rc == 1 )); then
        echo "WARNING: some files changed while tar was reading them, so those"
        echo "         entries may be inconsistent. The archive was kept."
        log_action "WARNING (tar exit 1, files changed during read): backup $src -> $archive"
    else
        log_action "OK: backup $src -> $archive"
    fi
}

# -------------------- List Backups --------------------
list_backups() {
    local -a backups
    echo
    rule
    echo "Available Backups:"
    rule

    shopt -s nullglob
    backups=( "$BACKUP_DIR"/*.tar.gz )
    shopt -u nullglob

    if (( ${#backups[@]} == 0 )); then
        echo "No backups found!"
    else
        ls -lh "${backups[@]}"
    fi
    rule
}

# -------------------- Menu --------------------
show_menu() {
    echo
    echo "============================================"
    echo "User Management & Backup Automation in Linux"
    echo "============================================"
    echo "USER MANAGEMENT:"
    echo " 1. Add User"
    echo " 2. Delete User"
    echo " 3. Modify User's Home Directory"
    echo " 4. List All Users"
    echo
    echo "GROUP MANAGEMENT:"
    echo " 5. Create Group"
    echo " 6. Delete Group"
    echo " 7. Add User to Group"
    echo " 8. Remove User from Group"
    echo " 9. List All Groups"
    echo "10. View User's Groups"
    echo "11. View Group Members"
    echo
    echo "BACKUP & LOGS:"
    echo "12. Backup Directory"
    echo "13. List Backups"
    echo "14. View Logs"
    echo "15. Clear Logs"
    echo
    echo "16. Exit"
    echo "============================================"
}

# -------------------- Main Loop --------------------
if (( EUID != 0 )) && ! command -v sudo >/dev/null 2>&1; then
    echo "WARNING: not running as root and 'sudo' was not found on PATH."
    echo "         Listing and log options will work; user and group changes will fail."
fi

while true; do
    show_menu
    if ! read -r -p "Enter your choice [1-16]: " choice; then
        echo
        exit 0
    fi

    case "$(trim "$choice")" in
         1) add_user ;;
         2) delete_user ;;
         3) modify_user ;;
         4) list_users ;;
         5) create_group ;;
         6) delete_group ;;
         7) add_user_to_group ;;
         8) remove_user_from_group ;;
         9) list_groups ;;
        10) view_user_groups ;;
        11) view_group_members ;;
        12) backup_directory ;;
        13) list_backups ;;
        14) view_logs ;;
        15) clear_logs ;;
        16) echo "Exiting..."; exit 0 ;;
         *) echo "Invalid choice. Please try again." ;;
    esac

    read -r -p "Press Enter to continue..." _ || exit 0
done
