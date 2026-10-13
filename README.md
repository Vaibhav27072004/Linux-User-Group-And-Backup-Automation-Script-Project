# 🐧 Linux User, Group & Backup Automation

**A single menu-driven tool that turns routine Linux administration into something you can hand to a junior admin without worrying about it.**

![Bash](https://img.shields.io/badge/Bash-4.4%2B-4EAA25?logo=gnubash&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-blue)
![Dependencies](https://img.shields.io/badge/dependencies-none-success)

No frameworks, no runtime, no install step. One POSIX-friendly Bash script, 16 operations, and an audit trail you can actually trust.

---

## 📌 The Real-World Problem

Every shared Linux machine — a college lab server, a small team's build box, a startup's staging host — runs into the same cycle:

> *"We've got 20 new students starting Monday. Each needs an account, a home directory, and membership in the right project group. Last semester we did it by hand and three accounts ended up in the wrong group. Nobody could tell us when it happened or who did it."*

Doing that manually means roughly five commands per person:

```bash
sudo useradd -m student01
sudo usermod -aG devops student01
id student01                      # did it actually work?
getent group devops               # is the group right?
echo "added student01" >> notes.txt   # the "audit trail"
```

Twenty people is around **100 commands typed by hand**, and every one of them is a chance to:

- **Typo a username** and create `studnet01`, which nobody notices for a week
- **Forget a flag** — `usermod -G` instead of `usermod -aG` silently *removes* every other group the user was in
- **Run the right command on the wrong account** — `userdel -r` is instant and takes the home directory with it
- **Assume it worked.** A command that fails prints to stderr and scrolls away. Your notes file still says "added".

That last point is the one that actually hurts. **A record that says something happened when it didn't is worse than no record at all** — it's the difference between an audit trail and a work of fiction.

---

## ✅ What This Project Does About It

It wraps all sixteen of those operations behind one numbered menu, and puts a **defensive layer** underneath them so the four failure modes above can't happen quietly.

| The classic failure | How this tool prevents it |
|---|---|
| Command fails, you think it succeeded | Every privileged command's exit status is captured. The log records `OK:` or `FAILED (exit N):` — never a success that didn't happen |
| `userdel -r` on the wrong account | Deleting a user requires **retyping the username**; the warning names what will be destroyed first |
| Typo creates a junk account | New names are validated against the standard Linux `NAME_REGEX` before `useradd` ever runs |
| Two backups overwrite each other | Timestamp is taken **per backup**, with a collision counter, so no archive can replace another |
| A failed backup leaves a corrupt `.tar.gz` | Archives are written to a `.part` file and moved into place only after `tar` succeeds |
| Logs scatter across the filesystem | `logs/` and `backup/` are anchored to the script's own directory, not your current one |
| A name like `-u` gets parsed as a flag | Names starting with `-` are rejected — `id -u` exits 0, so without this the script would believe that user exists |

**The point of the project isn't the menu. It's that the menu is safe to use when you're tired.**

---

## 🎬 See It Work

Real session output — two backups of the same directory taken seconds apart, then the log:

```text
============================================
User Management & Backup Automation in Linux
============================================
USER MANAGEMENT:
 1. Add User
 2. Delete User
 3. Modify User's Home Directory
 4. List All Users

GROUP MANAGEMENT:
 5. Create Group
 6. Delete Group
 7. Add User to Group
 8. Remove User from Group
 9. List All Groups
10. View User's Groups
11. View Group Members

BACKUP & LOGS:
12. Backup Directory
13. List Backups
14. View Logs
15. Clear Logs

16. Exit
============================================
Enter your choice [1-16]: 12
Enter directory path to backup: /home/vaibhav/projects/webapp
Backup created at: /home/vaibhav/app/backup/backup-webapp-2026-10-13-15-13-28.tar.gz
Size: 1.0K
```

Immediately again — note the `-1` suffix. The first archive is untouched:

```text
Enter your choice [1-16]: 12
Enter directory path to backup: /home/vaibhav/projects/webapp
Backup created at: /home/vaibhav/app/backup/backup-webapp-2026-10-13-15-13-28-1.tar.gz
Size: 1.0K
```

Both there, nothing lost:

```text
Enter your choice [1-16]: 13

-------------------------------------------
Available Backups:
-------------------------------------------
-rw-r--r-- 1 vaibhav vaibhav 206 Oct 13 15:13 backup-webapp-2026-10-13-15-13-28-1.tar.gz
-rw-r--r-- 1 vaibhav vaibhav 206 Oct 13 15:13 backup-webapp-2026-10-13-15-13-28.tar.gz
-------------------------------------------
```

And the audit trail, with the acting user and the real outcome:

```text
Enter your choice [1-16]: 14
-------------------------------------------
Activity Log (/home/vaibhav/app/logs/activity.log):
-------------------------------------------
2026-10-13 15:13:28 : [vaibhav] OK: backup /home/vaibhav/projects/webapp -> .../backup-webapp-2026-10-13-15-13-28.tar.gz
2026-10-13 15:13:28 : [vaibhav] OK: backup /home/vaibhav/projects/webapp -> .../backup-webapp-2026-10-13-15-13-28-1.tar.gz
-------------------------------------------
```

### When something goes wrong

The tool tells you, and the log agrees with reality:

```text
Enter your choice [1-16]: 1
Enter username to add: newuser
ERROR: 'useradd -m newuser' failed with exit status 5.
       No change was made (or the change is incomplete).
```

```text
2026-10-13 14:52:48 : [vaibhav] FAILED (exit 5): add user newuser
```

Bad input never reaches a privileged command:

```text
Enter username to add: Bad Name
Invalid name 'Bad Name'.
Use 1-32 characters: start with a lowercase letter or underscore,
then lowercase letters, digits, underscores or hyphens.

Enter username to delete: -u
Invalid name '-u': names cannot start with '-'.
```

Destructive actions make you say it twice:

```text
Enter username to delete: student01

WARNING: this permanently deletes the account 'student01' AND its home
         directory and mail spool. This cannot be undone.
Type the username again to confirm:
```

---

## 🔥 Features

### 👤 User Management
| # | Operation | Notes |
|---|---|---|
| 1 | Add user | Name validated against Linux `NAME_REGEX`; creates home directory |
| 2 | Delete user | Requires retyping the username to confirm |
| 3 | Modify home directory | Uses `usermod -m`, so existing files move with the account |
| 4 | List users | Reads `UID_MIN`/`UID_MAX` from `/etc/login.defs` instead of hardcoding 1000 |

### 👥 Group Management
| # | Operation | Notes |
|---|---|---|
| 5 | Create group | Validated name, existence checked first |
| 6 | Delete group | Confirmation prompt |
| 7 | Add user to group | Uses `usermod -aG` — appends, never replaces |
| 8 | Remove user from group | Both user and group verified to exist first |
| 9 | List all groups | Falls back gracefully if `column` is unavailable |
| 10 | View a user's groups | |
| 11 | View group members | |

### 🗂️ Backup Automation
| # | Operation | Notes |
|---|---|---|
| 12 | Backup a directory | Compressed `.tar.gz`, fresh timestamp per run, collision counter |
| 13 | List backups | |

Backup internals worth knowing:

- **Atomic**: written to `.part`, moved into place only on success
- **Relative paths**: uses `tar -C`, so no `Removing leading '/'` warnings and archives extract where you expect
- **Self-aware**: the script's own `logs/` and `backup/` are excluded, so backing up the project folder can't make `tar` read the archive it's writing
- **Honest about `tar` exit codes**: `1` means "files changed while reading" and keeps the archive with a warning; `2` or higher is fatal and discards it. Throwing away a usable archive over a non-fatal warning is its own kind of data loss

### 🧾 Logging
| # | Operation | Notes |
|---|---|---|
| 14 | View logs | All entries, or the last N |
| 15 | Clear logs | Confirmation required |

Every line carries a timestamp, the invoking user, and the real outcome:

```text
2026-10-13 15:13:28 : [vaibhav] OK: backup /home/vaibhav/projects/webapp -> ...
2026-10-13 14:52:48 : [vaibhav] FAILED (exit 5): add user newuser
```

`grep FAILED logs/activity.log` is a one-command incident report.

---

## ▶️ Quick Start

```bash
git clone https://github.com/Vaibhav27072004/Linux-User-Group-And-Backup-Automation-Script-Project.git
cd Linux-User-Group-And-Backup-Automation-Script-Project
chmod +x main.sh
./main.sh
```

That's it — no dependencies beyond a standard Linux userland.

**Requirements:** Bash 4.4+, `shadow-utils` (`useradd`/`usermod`/`groupadd`), `tar`, `gzip`, and GNU coreutils. All present by default on Ubuntu, Debian, Fedora, RHEL and Arch.

**Privileges:** user and group changes need root. Run the script with `sudo ./main.sh`, or run it as yourself and let it call `sudo` per command. Listing, backup and log options work unprivileged. If you're neither root nor have `sudo`, the script says so at startup rather than failing halfway through.

---

## 🧠 Design Decisions

The parts that took thought, and why they are the way they are:

**`set -uo pipefail`, deliberately not `set -e`.**
This is an interactive menu loop. With `set -e`, a single failed `useradd` would terminate the whole session and drop the admin back to their shell mid-task. Failures are caught explicitly instead, so the menu survives them.

**Every privileged command goes through one wrapper.**
```bash
run_action "User '$username' added successfully." \
           "add user $username" \
           priv useradd -m "$username"
```
`run_action` runs the command, captures the exit status, and decides what the user sees *and* what the log says from the actual result. One place to get right instead of sixteen.

**State is anchored to the script, not the shell.**
`logs/` and `backup/` resolve from the script's own location, so `~/scripts/main.sh` invoked from `/tmp` doesn't create `/tmp/logs/`. Without this, "View Logs" shows nothing depending on where you happened to be standing.

**One canonical path spelling.**
`readlink -f` and `cd && pwd` can return different strings for the same directory. Any path that gets *compared* goes through a single `canon_dir` helper first — otherwise a prefix test fails silently and the exclusion logic it guards quietly stops working.

**Names starting with `-` are rejected.**
`id -u` exits 0. Without that check, entering `-u` as a username passes the existence test, and the script then hands `-u` to a privileged command where it parses as a flag rather than an account name.

**`priv()` instead of hardcoding `sudo`.**
Running as root shouldn't require `sudo` to be installed at all.

---

## 📁 Project Structure

```text
.
├── main.sh              # The tool: 16 operations, ~595 lines
├── README.md
├── LICENSE              # MIT
├── .gitignore           # keeps logs/ and backup/ out of version control
├── .gitattributes       # pins *.sh to LF endings
│
├── logs/                # created on first run
│   └── activity.log
│
└── backup/              # created on first run
    └── backup-<name>-<timestamp>.tar.gz
```

`.gitattributes` exists for a specific reason: a shell script checked out with CRLF line endings on Windows and then run on Linux dies with `bad interpreter: /bin/bash^M`. Pinning `*.sh` to `eol=lf` stops that before it happens.

---

## 🧪 Verification Status

Honest accounting of what has and hasn't been exercised.

**Verified by running the script:**

| Area | What was checked |
|---|---|
| Backup naming | Three backups of one directory in one session produce three distinct archives |
| Atomic writes | No `.part` files left behind after a failed run |
| Self-exclusion | Backing up the project folder excludes `logs/` and `backup/`; backing up `backup/` itself succeeds |
| `tar` exit codes | `1` keeps the archive and warns; `2`+ discards and fails |
| Audit accuracy | A genuinely failing `useradd` logs `FAILED (exit 5)`, not a success |
| Input validation | Empty, whitespace, uppercase, digit-leading and `-`-leading names all rejected; non-numeric line counts rejected |
| Path anchoring | Invoked from an unrelated directory, zero files created there |
| Syntax | `bash -n` clean |

**Not yet verified:** the seven privileged operations themselves — `useradd`, `userdel`, `usermod`, `groupadd`, `groupdel`, `gpasswd`. The error-handling layer around them is tested; the commands behind it need a run on a real Linux host. A `shellcheck` pass is also still pending.

If you're evaluating this project, that distinction is the honest one: **the plumbing is proven, the privileged calls need a VM run.**

---

## 🚀 Roadmap

- [ ] Automated smoke test in a Docker container, covering menu items 1–11
- [ ] `shellcheck` in CI
- [ ] Password policy: set an initial password, `chage -d 0` to force a change at first login
- [ ] Non-interactive flags (`--add-user`, `--backup`) so the tool is usable from `cron`
- [ ] Scheduled backups with retention (keep last N)
- [ ] Export the log as CSV/JSON for ingestion into a SIEM
- [ ] Write the audit trail to `syslog` via `logger`, so it can't be cleared by whoever ran the command
- [ ] Include primary-group members in "View Group Members", not just secondary

---

## 🤝 Author

**Vaibhav Kumar Sahu**
Developer | DevOps & Cybersecurity Enthusiast

---

## 📜 License

Released under the [MIT License](LICENSE) — free to use, modify and distribute.
