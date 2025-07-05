# top10_validator.sh - v2.1.0 - 2025-07-05 05:41:43

[![Version](https://img.shields.io/badge/version-2.1.0-purple.svg)](./top10_validator.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/top10_validator.md)
[![Size](https://img.shields.io/badge/size-13KB-yellow)](./top10_validator.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--05-blue)](./top10_validator.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--21-red)](https://www.gnu.org/software/bash/)

## Table of Contents
- High-level summary - top10_validator.sh
- Variables Set - top10_validator.sh

## High-level summary - top10_validator.sh
- top10_validator.sh: Check a script against our Bash Top 10 (Color + Markdown)
- Enable strict mode for safety and fail-fast behavior
- Disable strict mode temporarily when parsing or processing risky logic
- Enable strict mode again after risky logic
- Define color variables for output formatting
- Define status icons
- Declare rule arrays and tracking levels
- Define Top 10 validation rules (plus bonus)
- Function to show usage help
- Parse command-line arguments
- Initialize flag variables
- Process each argument
- Validate input script
- Initialize LEVELs to 'bad'
- Disable strict mode for grep/parsing sections
- Run checks 10 to 0
- Output Results
- Final Score Calculation
- Build Summary Block
- Terminal output
- Markdown output
- Count results
- Bonus and score logic

## Variables Set - top10_validator.sh
- BADGE
- CHECK
- CROSS
- HEADER
- HIDE_SCRIPT_NAME
- MD_OUT
- QUIET_HEADER
- RISK_TEXT
- SCRIPT
- SHOW_FOOTER
- STAR
- VERSION
- WARN
