#!/usr/bin/env bash
set -euo pipefail

# vault_radar_validator.sh
VERSION="1.1.0"
AUTHOR="raymon.epping"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

log_info()  { echo -e "ℹ️  $1"; }
log_warn()  { echo -e "⚠️  $1"; }
log_error() { echo -e "❌ $1"; exit 1; }

validate_flags() {
  local -n _flags_ref=$1
  local debug="${_flags_ref[debug]:-false}"
  local compact=false

  [[ "$debug" == "compact" ]] && compact=true && _flags_ref[debug]="true"

  for flag in create build fresh commit request quiet status; do
    _flags_ref[$flag]="${_flags_ref[$flag]:-false}"
    if [[ "${_flags_ref[$flag]}" != "true" && "${_flags_ref[$flag]}" != "false" ]]; then
      log_error "Invalid boolean for --$flag: ${_flags_ref[$flag]}"
    fi
  done

  _flags_ref[language]="${_flags_ref[language]:-bash}"
  _flags_ref[scenario]="${_flags_ref[scenario]:-AWS}"
  _flags_ref[debug]="${_flags_ref[debug]:-false}"

  if [[ "${_flags_ref[build]}" != "true" && \
        ( "${_flags_ref[language]}" != "bash" || "${_flags_ref[scenario]}" != "AWS" ) ]]; then
    log_warn "Explicit --language=${_flags_ref[language]} and/or --scenario=${_flags_ref[scenario]} given but --build=false"
    log_info "Auto-correcting: setting --build=true"
    _flags_ref[build]="true"
  fi
}
