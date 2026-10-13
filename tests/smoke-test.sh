#!/bin/bash
#
# Smoke test for main.sh's privileged operations (menu items 1-11).
#
# These are the operations that cannot be exercised on a non-Linux host, because
# useradd/userdel/usermod/groupadd/groupdel/gpasswd/getent do not exist there.
#
# It creates and deletes REAL users and groups, so it refuses to run outside a
# container unless you override the guard deliberately:
#
#   docker run --rm -i ubuntu:24.04 bash -s < tests/smoke-test.sh
#
# Exits 0 if every assertion passed, 1 otherwise.

set -uo pipefail

U="smoketest_user"
G="smoketest_group"
NEW_HOME="/home/smoketest_moved"

pass=0
fail=0

if [[ -t 1 ]]; then
    C_OK=$'\033[32m'; C_NO=$'\033[31m'; C_HD=$'\033[1m'; C_Z=$'\033[0m'
else
    C_OK=''; C_NO=''; C_HD=''; C_Z=''
fi

ok()  { printf '  %sPASS%s  %s\n' "$C_OK" "$C_Z" "$1"; pass=$((pass + 1)); }
bad() { printf '  %sFAIL%s  %s\n' "$C_NO" "$C_Z" "$1"; fail=$((fail + 1)); }

# check <description> <command...>   -- passes when the command succeeds
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
# refute <description> <command...>  -- passes when the command FAILS
refute() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d"; else ok "$d"; fi; }

# contains <description> <haystack> <needle> -- passes when needle is in haystack
contains() { if grep -q -- "$3" <<<"$2"; then ok "$1"; else bad "$1"; fi; }

section() { printf '\n%s== %s%s\n' "$C_HD" "$1" "$C_Z"; }

# ---------------------------------------------------------------- preconditions

if (( EUID != 0 )); then
    echo "This test must run as root (it creates and deletes users)." >&2
    exit 1
fi

if [[ ! -e /.dockerenv && "${SMOKE_ALLOW_UNSAFE:-}" != "1" ]]; then
    echo "Refusing to run outside a container: this test deletes real users." >&2
    echo "Set SMOKE_ALLOW_UNSAFE=1 if you really mean to run it on this host." >&2
    exit 1
fi

for c in useradd userdel usermod groupadd groupdel gpasswd getent tar; do
    command -v "$c" >/dev/null 2>&1 || { echo "Missing required command: $c" >&2; exit 1; }
done

# Locate main.sh: next to this script's parent, or via $MAIN_SH.
if [[ -n "${MAIN_SH:-}" ]]; then
    SCRIPT="$MAIN_SH"
elif [[ -f "$(dirname "$0")/../main.sh" ]]; then
    SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/main.sh"
elif [[ -f ./main.sh ]]; then
    SCRIPT="$(pwd)/main.sh"
else
    echo "Cannot find main.sh. Set MAIN_SH=/path/to/main.sh." >&2
    exit 1
fi

LOG="$(cd "$(dirname "$SCRIPT")" && pwd)/logs/activity.log"

echo "Testing : $SCRIPT"
echo "Log     : $LOG"

# Feed a menu sequence to the script. Each call ends by exiting the menu.
drive() { printf '%b' "$1" | bash "$SCRIPT" >/dev/null 2>&1; }

# Start from a known state.
userdel -r "$U" &>/dev/null || true
groupdel "$G" &>/dev/null || true
rm -rf "$NEW_HOME"
rm -f "$LOG"

# ------------------------------------------------------------------ 1: add user

section "1. Add User"
drive "1\n$U\n\n16\n"
check  "account '$U' exists"                 id "$U"
check  "home directory /home/$U was created" test -d "/home/$U"

section "5. Create Group"
drive "5\n$G\n\n16\n"
check  "group '$G' exists"                   getent group "$G"

# ------------------------------------------------- 7: add to group (the -aG trap)

section "7. Add User to Group"
before="$(id -nG "$U" | tr ' ' '\n' | sort)"
drive "7\n$U\n$G\n\n16\n"
after="$(id -nG "$U" | tr ' ' '\n' | sort)"

if id -nG "$U" | tr ' ' '\n' | grep -qx "$G"; then
    ok "'$U' is now a member of '$G'"
else
    bad "'$U' is now a member of '$G'"
fi

# usermod -G (without -a) silently drops every other group. Prove it did not.
lost="$(comm -23 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))"
if [[ -z "$lost" ]]; then
    ok "no pre-existing groups were lost (usermod -aG, not -G)"
else
    bad "pre-existing groups were LOST: $(echo "$lost" | tr '\n' ' ')"
fi

section "8. Remove User from Group"
drive "8\n$U\n$G\n\n16\n"
if id -nG "$U" | tr ' ' '\n' | grep -qx "$G"; then
    bad "'$U' was removed from '$G'"
else
    ok "'$U' was removed from '$G'"
fi

# ------------------------------------------- 3: modify home (does -m move files?)

section "3. Modify User's Home Directory"
echo "marker" > "/home/$U/marker.txt"
chown "$U" "/home/$U/marker.txt"
drive "3\n$U\n$NEW_HOME\n\n16\n"

recorded="$(getent passwd "$U" | cut -d: -f6)"
if [[ "$recorded" == "$NEW_HOME" ]]; then
    ok "passwd entry now points at $NEW_HOME"
else
    bad "passwd entry says '$recorded', expected '$NEW_HOME'"
fi
check  "new home directory exists"                   test -d "$NEW_HOME"
check  "existing files MOVED with the account"       test -f "$NEW_HOME/marker.txt"
refute "old home directory is gone"                  test -d "/home/$U"

# ------------------------------------------------------------------- 4,9,10,11

section "4, 9, 10, 11. Read-only views"
out="$(printf '4\n\n16\n' | bash "$SCRIPT" 2>&1)"
contains "List Users prints a header" "$out" "Regular Users"
contains "List Users includes '$U'"   "$out" "$U"

out="$(printf '9\n\n16\n' | bash "$SCRIPT" 2>&1)"
contains "List Groups prints a header" "$out" "System Groups"
contains "List Groups includes 'root'" "$out" "root"

out="$(printf '10\n%s\n\n16\n' "$U" | bash "$SCRIPT" 2>&1)"
contains "View User's Groups works" "$out" "Groups for user"

drive "7\n$U\n$G\n\n16\n"   # re-add so there is a member to show
out="$(printf '11\n%s\n\n16\n' "$G" | bash "$SCRIPT" 2>&1)"
contains "View Group Members lists '$U'" "$out" "$U"

# -------------------------------------------------------- validation must block

section "Input validation blocks bad names"
drive "1\nBad Name\n\n16\n"
refute "'Bad Name' was not created"    id "Bad Name"
drive "1\n9bad\n\n16\n"
refute "'9bad' was not created"        id "9bad"
drive "5\nBAD\n\n16\n"
refute "group 'BAD' was not created"   getent group "BAD"

# ----------------------------------------------------------- 2, 6: destructive

section "2. Delete User"
drive "2\n$U\n$U\n\n16\n"
refute "account '$U' is gone"          id "$U"
refute "home directory was removed"    test -d "$NEW_HOME"

section "6. Delete Group"
drive "6\n$G\nyes\n\n16\n"
refute "group '$G' is gone"            getent group "$G"

# ------------------------------------------------------------- the audit trail

section "Audit log honesty"
if [[ -f "$LOG" ]]; then
    ok "log file was created"
    n_failed="$(grep -c 'FAILED' "$LOG" || true)"
    if [[ "$n_failed" == "0" ]]; then
        ok "no FAILED entries (every operation really succeeded)"
    else
        bad "$n_failed FAILED entries in the log:"
        grep 'FAILED' "$LOG" | sed 's/^/        /'
    fi
    for want in "add user $U" "create group $G" "add user $U to group $G" \
                "remove user $U from group $G" "modify user $U" \
                "delete user $U" "delete group $G"; do
        if grep -q "OK: $want" "$LOG"; then
            ok "logged OK: $want"
        else
            bad "missing log entry: OK: $want"
        fi
    done
    if grep -q "\[root\]" "$LOG"; then
        ok "entries record the acting user"
    else
        bad "entries record the acting user"
    fi
else
    bad "log file was created"
fi

# ------------------------------------------------------------------- summary

printf '\n%s== Summary%s\n' "$C_HD" "$C_Z"
printf '  passed: %d\n  failed: %d\n' "$pass" "$fail"

if (( fail > 0 )); then
    printf '\n%sSMOKE TEST FAILED%s\n' "$C_NO" "$C_Z"
    exit 1
fi
printf '\n%sSMOKE TEST PASSED%s\n' "$C_OK" "$C_Z"
