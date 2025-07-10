# 🛡️ Radar Love Project Backups

[![Backups](https://img.shields.io/badge/Backups-Automated-green)](#)
[![Integrity](https://img.shields.io/badge/Integrity-Checked-brightgreen)](#)
[![Last Backup](https://img.shields.io/badge/Last_Backup-v2.9.0-blue)](#)

---

## 🔢 Last 5 Backups

| Date/Time           | Tag         | Parent  | Commit    | Filename                        | Size     | SHA256                             | Status   |
|---------------------|-------------|---------|-----------|----------------------------------|----------|-------------------------------------|----------|
| 2025-07-10 17:29:34 | v2.8.0 | v2.8.0 | a15ac104cb25a42eb9a55fcfe699fd9806a49b09 | v2.8.0_20250710_172934.tar.gz | 60K | 9f69bb63eea4a78f46c15dd944fbcbff212c5b27879722e3a69a5959fe23209e | ok |
| 2025-07-10 17:30:51 | v2.8.0 | v2.8.0 | a15ac104cb25a42eb9a55fcfe699fd9806a49b09 | v2.8.0_20250710_173051.tar.gz | 60K | 259e8e4281177e413b969396b692bff9c15edd3643c799c85a19039260a0ac28 | ok |
| 2025-07-10 17:37:38 | v2.8.0 | v2.8.0 | a15ac104cb25a42eb9a55fcfe699fd9806a49b09 | v2.8.0_20250710_173738.tar.gz | 60K | d40759111608b9fde95307469a09a1a9b25488febf930c75f061db5a530f7284 | ok |
| 2025-07-10 17:40:13 | v2.8.0 | v2.8.0 | a15ac104cb25a42eb9a55fcfe699fd9806a49b09 | v2.8.0_20250710_174013.tar.gz | 60K | 6713442cdaf761df1d0979a2fbf41a7f1d9d3c9129354a4d2d6cc4fbfc7fbe6e | ok |
| 2025-07-10 21:33:40 | v2.9.0 | v2.9.0 | b7f368311462bfffe77231b5c3c5654c95355941 | v2.9.0_20250710_213340.tar.gz | 60K | edf0e3beef45caff4ff6881e510c2ed1f0593e7e877ed5e0673af6b149971a44 | ok |

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

v2.9.0: Latest backup tag

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
