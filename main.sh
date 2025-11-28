#!/bin/bash

LOG_FILE="logs/activity.log"
BACKUP_DIR="backup"
DATE=$(date +%Y-%m-%d-%H-%M-%S)

mkdir -p logs backup

log_action() {
    echo "$(date +"%F %T") : $1" >> "$LOG_FILE"
}

# -------------------- Add User --------------------
add_user() {
    read -p "Enter username to add: " username
    username=$(echo "$username" | tr -d ' \t\n\r')

    if id "$username" &>/dev/null; then
        echo "User '$username' already exists!"
    else
        sudo useradd -m "$username"
        echo "User '$username' added successfully."
        log_action "Added user $username"
    fi
}

# -------------------- Delete User --------------------
delete_user() {
    read -p "Enter username to delete: " username
    if id "$username" &>/dev/null; then
        sudo userdel -r "$username"
        echo "User '$username' deleted successfully."
        log_action "Deleted user $username"
    else
        echo "User '$username' not found!"
    fi
}

# ---------------- Modify User's Home Directory ----------------
modify_user() {
    read -p "Enter username to modify: " username
    if id "$username" &>/dev/null; then
        read -p "Enter new home directory: " new_home
        sudo usermod -d "$new_home" "$username"
        echo "Home directory of '$username' changed to $new_home"
        log_action "Modified user $username (new home: $new_home)"
    else
        echo "User not found!"
    fi
}

# -------------------- Create Group --------------------
create_group() {
    read -p "Enter group name: " group
    if getent group "$group" &>/dev/null; then
        echo "Group already exists!"
    else
        sudo groupadd "$group"
        echo "Group '$group' created."
        log_action "Created group $group"
    fi
}

# -------------------- Add User to Group --------------------
add_user_to_group() {
    read -p "Enter username: " username
    if id "$username" &>/dev/null; then
        read -p "Enter group name: " group
        if getent group "$group" &>/dev/null; then
            sudo usermod -aG "$group" "$username"
            echo "User '$username' added to group '$group' successfully."
            log_action "Added user $username to group $group"
        else
            echo "Group '$group' does not exist!"
        fi
    else
        echo "User '$username' not found!"
    fi
}

# -------------------- Remove User from Group --------------------
remove_user_from_group() {
    read -p "Enter username: " username
    if id "$username" &>/dev/null; then
        read -p "Enter group name: " group
        if getent group "$group" &>/dev/null; then
            sudo gpasswd -d "$username" "$group"
            echo "User '$username' removed from group '$group' successfully."
            log_action "Removed user $username from group $group"
        else
            echo "Group '$group' does not exist!"
        fi
    else
        echo "User '$username' not found!"
    fi
}

# -------------------- Delete Group --------------------
delete_group() {
    read -p "Enter group name to delete: " group
    if getent group "$group" &>/dev/null; then
        sudo groupdel "$group"
        echo "Group '$group' deleted successfully."
        log_action "Deleted group $group"
    else
        echo "Group '$group' not found!"
    fi
}

# -------------------- List Users --------------------
list_users() {
    echo ""
    echo "-------------------------------------------"
    echo "System Users (UID ≥ 1000):"
    echo "-------------------------------------------"
    awk -F: '$3 >= 1000 && $3 < 65534 {print "Username: " $1 "\tUID: " $3 "\tHome: " $6}' /etc/passwd
    echo "-------------------------------------------"
}

# -------------------- List Groups --------------------
list_groups() {
    echo ""
    echo "-------------------------------------------"
    echo "System Groups:"
    echo "-------------------------------------------"
    cut -d: -f1 /etc/group | column
    echo "-------------------------------------------"
}

# -------------------- View User's Groups --------------------
view_user_groups() {
    read -p "Enter username: " username
    if id "$username" &>/dev/null; then
        echo "-------------------------------------------"
        echo "Groups for user '$username':"
        echo "-------------------------------------------"
        groups "$username"
        echo "-------------------------------------------"
    else
        echo "User '$username' not found!"
    fi
}

# -------------------- View Group Members --------------------
view_group_members() {
    read -p "Enter group name: " group
    if getent group "$group" &>/dev/null; then
        echo "-------------------------------------------"
        echo "Members of group '$group':"
        echo "-------------------------------------------"
        getent group "$group" | cut -d: -f4
        echo "-------------------------------------------"
    else
        echo "Group '$group' not found!"
    fi
}

# -------------------- View Logs --------------------
view_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo "-------------------------------------------"
        echo "Activity Log ($LOG_FILE):"
        echo "-------------------------------------------"
        read -p "View (a)ll logs or last (n) lines? [a/n]: " view_choice
        case $view_choice in
            a|A) cat "$LOG_FILE" ;;
            n|N)
                read -p "Enter number of lines: " num_lines
                tail -n "$num_lines" "$LOG_FILE"
                ;;
            *) echo "Invalid choice!" ;;
        esac
        echo "-------------------------------------------"
    else
        echo "Log file not found!"
    fi
}

# -------------------- Clear Logs --------------------
clear_logs() {
    read -p "Are you sure you want to clear all logs? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        > "$LOG_FILE"
        echo "Logs cleared successfully."
        log_action "Cleared all logs"
    else
        echo "Operation cancelled."
    fi
}

# -------------------- Backup Directory --------------------
backup_directory() {
    read -p "Enter directory path to backup: " dir
    if [ -d "$dir" ]; then
        tar -czf "$BACKUP_DIR/backup-$DATE.tar.gz" "$dir"
        echo "Backup created at: $BACKUP_DIR/backup-$DATE.tar.gz"
        log_action "Backed up directory $dir"
    else
        echo "Directory not found!"
    fi
}

# -------------------- List Backups --------------------
list_backups() {
    echo ""
    echo "-------------------------------------------"
    echo "Available Backups:"
    echo "-------------------------------------------"

    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR)" ]; then
        ls -lh "$BACKUP_DIR"
    else
        echo "No backups found!"
    fi

    echo "-------------------------------------------"
}

# -------------------- Menu --------------------
show_menu() {
    echo ""
    echo "============================================"
    echo "User Management & Backup Automation in Linux"
    echo "============================================"
    echo "USER MANAGEMENT:"
    echo " 1. Add User"
    echo " 2. Delete User"
    echo " 3. Modify User"
    echo " 4. List All Users"
    echo ""
    echo "GROUP MANAGEMENT:"
    echo " 5. Create Group"
    echo " 6. Delete Group"
    echo " 7. Add User to Group"
    echo " 8. Remove User from Group"
    echo " 9. List All Groups"
    echo "10. View User's Groups"
    echo "11. View Group Members"
    echo ""
    echo "BACKUP & LOGS:"
    echo "12. Backup Directory"
    echo "13. List Backups"
    echo "14. View Logs"
    echo "15. Clear Logs"
    echo ""
    echo "16. Exit"
    echo "============================================"
}

# -------------------- Main Loop --------------------
while true; do
    show_menu
    read -p "Enter your choice [1-16]: " choice

    case $choice in
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
       16) echo "Exiting…"; exit 0 ;;
       *) echo "Invalid choice. Please try again." ;;
    esac

    read -p "Press Enter to continue…"
done
