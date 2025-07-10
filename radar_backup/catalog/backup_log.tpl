# 🛡️ Radar Love Project Backups

[![Backups](https://img.shields.io/badge/Backups-Automated-green)](#)
[![Integrity](https://img.shields.io/badge/Integrity-Checked-brightgreen)](#)
[![Last Backup](https://img.shields.io/badge/Last_Backup-{{LAST_BACKUP}}-blue)](#)

---

## 🔢 Last {{MAX_SUMMARY}} Backups

| Date/Time           | Tag         | Parent  | Commit    | Filename                        | Size     | SHA256                             | Status   |
|---------------------|-------------|---------|-----------|----------------------------------|----------|-------------------------------------|----------|
{{SUMMARY_ROWS}}

---

## 🔍 Exclusions (from `.backupignore` / config):

{{EXCLUSIONS}}

---

## ✅ Integrity Check Results

{{INTEGRITY}}

---

*Backups are stored in `backup/` for quick restore. To recover, use `./radar_backup.sh --restore <filename>`.*

---
Variables explained:

{{LAST_BACKUP}}: Latest backup tag

{{MAX_SUMMARY}}: Number of summary rows to show (e.g. 5)

{{SUMMARY_ROWS}}: Table rows with last backups info

{{EXCLUSIONS}}: Text block with patterns

{{INTEGRITY}}: Markdown/text block (passed/failed, hash check, etc)