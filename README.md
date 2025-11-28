# 🚀 Linux User, Group & Backup Automation Script
*A Complete Automation Tool for Linux System Administration*

---

## 📌 Overview
Managing users, groups, and backups manually in Linux can be repetitive, time-consuming, and prone to human error.  
This project provides a **Bash-based automation tool** that simplifies system administration using a **menu-driven command-line interface**.

It centralizes all essential user/group operations, directory backups, and log management in a single, easy-to-use script.

---

## ❗ Problem Statement
Linux system administrators face several challenges:

- Repetitive execution of user and group commands  
- Higher chance of mistakes during manual administration  
- No central interface to manage all tasks  
- Hard to maintain proper logs and audit trails  
- Manual backups can be inconsistent  

These challenges reduce efficiency and increase administrative workload.

---

## ✅ Our Solution
We developed a **fully automated Linux administration tool** that solves these challenges by:

- Providing a single **menu-based interface**  
- Automating user & group creation/deletion  
- Managing directory backups with timestamps  
- Maintaining activity logs for auditing  
- Reducing effort and minimizing human errors  
- Offering a clean, modular, maintainable Bash script  

This works like a **lightweight Linux system management assistant**.

---

## 🔥 Key Features

### 👤 User Management
- Add new users  
- Delete users  
- Modify user home directories  
- List all system users  

### 👥 Group Management
- Create groups  
- Delete groups  
- Add user to a group  
- Remove user from group  
- View all groups  
- View group members  
- View groups of a user  

### 🗂️ Backup Automation
- Backup any directory  
- Create `.tar.gz` compressed backups  
- Auto–timestamp each backup  
- List available backups  

### 🧾 Logging System
- Every action stored in `logs/activity.log`  
- View all logs or last N entries  
- Clear logs anytime  

---

## 🛠️ Technologies Used

### **Shell Scripting**
- Bash (`#!/bin/bash`)  
- Functions, loops, input/output, conditions

### **Linux Admin Commands**
- `useradd`, `userdel`, `usermod`  
- `groupadd`, `groupdel`, `gpasswd`

### **Text Processing Tools**
- `awk`, `cut`, `grep`, `tail`, `column`

### **Backup Utility**
- `tar -czf` for compressed backups

### **System Files Used**
- `/etc/passwd`  
- `/etc/group`  
- Log: `logs/activity.log`  
- Backups: `backup/`

---

## 📁 Project Structure
project-folder/
│
├── automation.sh # Main Script
│
├── logs/
│ └── activity.log # Log file storing all actions
│
└── backup/
└── backup-*.tar.gz # Timestamped backup files

---

## ▶️ How to Run the Script

### **1️⃣ Clone the Repository**
```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO

2️⃣ Make the Script Executable
chmod +x automation.sh

3️⃣ Run the Script
./automation.sh

===============================================
 User Management & Backup Automation in Linux
===============================================
 USER MANAGEMENT:
  1. Add User
  2. Delete User
  3. Modify User
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
===============================================




## **🧪 Testing **
-----------------------------------------------
Tested on multiple Linux distributions:

- Ubuntu
- Debian
- Kali Linux
- Fedora

Testing included:

- User & group management
- Backup creation & extraction
- Log generation & clearing
- Error handling for invalid input
------------------------------------------------

## **🚀 Future Enhancements **
========================================
- Add colorful UI for better UX
- Password expiry & policy management
- Scheduled backups via cron
- Convert script into .deb package
- System monitoring (CPU/RAM/Disk)
- Export logs to CSV/JSON
- Role-based access
=========================================

## **🤝 Author **
Vaibhav Kumar Sahu
Developer | DevOps and Cybersecurity Enthusiast

## **📜 License **
This project is open-source and free to use under the MIT License.
