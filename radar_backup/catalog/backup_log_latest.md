# 🛡️ Radar Love Project Backups

[![Backups](https://img.shields.io/badge/Backups-Automated-green)](#)
[![Integrity](https://img.shields.io/badge/Integrity-Checked-brightgreen)](#)
[![Last Backup](https://img.shields.io/badge/Last_Backup-v2.1.15-blue)](#)

---

## 🔢 Last 5 Backups

| Date/Time           | Tag         | Parent  | Commit    | Filename                        | Size     | SHA256                             | Status   |
|---------------------|-------------|---------|-----------|----------------------------------|----------|-------------------------------------|----------|
| 2025-07-10 15:23:01 | v2.1.15 | v2.1.15 | 65a49c770ae678c9596fa738fb880ddade1b3c09 | v2.1.15_20250710_152301.tar.gz | 60K | 0260f6069b44784534b28a1f5c0a675b693d97549c26ac210a08bd01ad059cfd | ok |

---

## 🔍 Exclusions (from `.backupignore` / config):


bin/.DS_Store
.backup.json
radar_love_cli*.gz
node_modules/
.git/
*.swp
backup/
restore_*
bin/.DS_Store

---

## ✅ Integrity Check Results


All backup SHA256 checks: OK

---

*Backups are stored in `backup/` for quick restore. To recover, use `./radar_backup.sh --restore <filename>`.*

---
Variables explained:

v2.1.15: Latest backup tag

5: Number of summary rows to show (e.g. 5)


: Text block with patterns
bin/.DS_Store
.backup.json
radar_love_cli*.gz
node_modules/
.git/
*.swp
backup/
restore_*
bin/.DS_Store

: Markdown/text block (passed/failed, hash check, etc)
All backup SHA256 checks: OK
