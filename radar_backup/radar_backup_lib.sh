#!/usr/bin/env bash
# --- radar_backup_lib.sh ---
# Modular backup/restore/prune/summary logic for Radar Love (and friends)
VERSION="1.0.9"

# --- COLORS & ICONS ---
color_reset=$'\e[0m'
color_green=$'\e[32m'
color_red=$'\e[31m'
color_yellow=$'\e[33m'
color_blue=$'\e[34m'
color_bold=$'\e[1m'

icon_ok="✅"
icon_warn="⚠️"
icon_err="❌"
icon_zip="🗜️"
icon_back="🔄"
icon_restore="💾"
icon_prune="🧹"
icon_info="ℹ️"

backup_log()   { [[ $QUIET == "true" ]] && return; echo "${color_blue}[backup]${color_reset} $*"; }
backup_ok()    { [[ $QUIET == "true" ]] && return; echo "${color_green}${icon_ok} $*${color_reset}"; }
backup_warn()  { [[ $QUIET == "true" ]] && return; echo "${color_yellow}${icon_warn} $*${color_reset}"; }
backup_err()   { echo "${color_red}${icon_err} $*${color_reset}" >&2; }
backup_info()  { [[ $QUIET == "true" ]] && return; echo "${color_bold}${icon_info} $*${color_reset}"; }

# --- Get includes/excludes as newline blobs (no declare) ---
get_backup_config_blobs() {
  # local config_file="$1/.backup.json"
  # local ignore_file="$1/.backupignore"

  local config_file="$1"
  local ignore_file="$(dirname "$config_file")/.backupignore"


  local includes=() excludes=()
  if [[ -f "$config_file" ]]; then
    if ! jq -e . "$config_file" &>/dev/null; then
      backup_err "Malformed JSON in $config_file"
      return 1
    fi
    mapfile -t includes < <(jq -r '.include[]?' "$config_file" 2>/dev/null)
    mapfile -t excludes < <(jq -r '.exclude[]?' "$config_file" 2>/dev/null)
    if [[ -f "$ignore_file" ]]; then
      mapfile -t extra_excludes < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$ignore_file")
      excludes+=("${extra_excludes[@]}")
    fi
  elif [[ -f "$ignore_file" ]]; then
    includes=(".")
    mapfile -t excludes < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$ignore_file")
  else
    includes=(".")
    excludes=(".git" "backup" "restore_*" "*.log")
  fi
  printf '%s\n' "${includes[@]}"
  echo "---END---"
  printf '%s\n' "${excludes[@]}"
}

# --- Create tar.gz backup archive with include/exclude blobs ---
create_backup_archive() {
  local root="$1" tag="$2" includes_blob="$3" excludes_blob="$4" backup_dir="$5" dryrun="${6:-false}"
  local dt archive_name
  dt=$(date "+%Y%m%d_%H%M%S")
  archive_name="${tag:-untagged}_${dt}.tar.gz"

  mapfile -t includes <<<"$includes_blob"
  mapfile -t excludes <<<"$excludes_blob"

  local exclude_args=()
  for ex in "${excludes[@]}"; do
    [[ -n "$ex" ]] && exclude_args+=("--exclude=$ex")
  done

  local include_args=()
  for inc in "${includes[@]}"; do
    [[ -e "$root/$inc" ]] && include_args+=("$inc")
  done

  backup_log "Tar include args: ${include_args[*]}" >&2
  backup_log "Tar exclude args: ${exclude_args[*]}" >&2

  if [[ "${#include_args[@]}" -eq 0 ]]; then
    backup_warn "No includes found! Archive will not be created."
    return 1
  fi

  if [[ "$dryrun" == "true" ]]; then
    backup_warn "Dryrun: would create archive $archive_name in $backup_dir"
    return 0
  fi

  (cd "$root" && tar czf "$backup_dir/$archive_name" "${exclude_args[@]}" "${include_args[@]}")
  echo "$archive_name"
}

# --- Main backup logic (only uses blobs) ---
backup_project() {
  local root="$1" backup_dir="$2" mdlog="$3" tpl="$4" N="$5" dryrun="${6:-false}" config_file="$7"
  mkdir -p "$backup_dir"

  local arr_blobs includes_blob excludes_blob
  # if ! arr_blobs=$(get_backup_config_blobs "$root"); then
  if ! arr_blobs=$(get_backup_config_blobs "$config_file"); then
    backup_err "Skipping backup for $root due to config errors."
    return 1
  fi
  includes_blob=$(awk '/^---END---/ {exit} {print}' <<<"$arr_blobs")
  excludes_blob=$(awk 'flag {print} /^---END---/ {flag=1}' <<<"$arr_blobs")

  mapfile -t includes_arr <<<"$includes_blob"
  mapfile -t excludes_arr <<<"$excludes_blob"

  read -r tag commit parent <<<"$(get_git_tag_info "$root")"
  local archive_name archive_path sha size dt
  dt=$(date "+%Y-%m-%d %H:%M:%S")

  backup_ok "Detected root: $root"
  backup_log "Includes: ${includes_arr[*]}"
  backup_log "Excludes: ${excludes_arr[*]}"
  backup_log "Using tag: $tag (parent: $parent, commit: $commit)"

  if [[ "$dryrun" == "true" ]]; then
    backup_warn "Dryrun enabled: would create archive and log, but skipping."
    create_backup_archive "$root" "$tag" "$includes_blob" "$excludes_blob" "$backup_dir" "true"
    return 0
  fi

  archive_name=$(create_backup_archive "$root" "$tag" "$includes_blob" "$excludes_blob" "$backup_dir")
  archive_path="$backup_dir/$archive_name"

  if [[ -f "$archive_path" ]]; then
    sha=$(get_sha256 "$archive_path")
    size=$(du -h "$archive_path" | awk '{print $1}')
    add_log_md "$mdlog" "$dt" "$tag" "$parent" "$commit" "$archive_name" "$size" "$sha" "ok"
    backup_ok "Backup created: $archive_path ($size)"
  else
    backup_err "Archive not created: $archive_path"
    return 1
  fi

  local summary_file
  summary_file=$(mktemp)
  get_last_n_backups "$mdlog" "$N" >"$summary_file"
  write_log_md_from_tpl "$tpl" "${mdlog%.md}_latest.md" "$summary_file"
  rm -f "$summary_file"
}

restore_backup() {
  local backup_dir="$1" file="$2" root="$3" dryrun="${4:-false}"
  local full_path="$file"
  if [[ ! "$file" = /* ]] && [[ ! "$file" == ./* ]] && [[ ! "$file" == ../* ]]; then
    full_path="$backup_dir/$file"
  fi

  if [[ ! -f "$full_path" ]]; then
    backup_err "Backup file not found: $full_path"
    return 1
  fi

  local restore_dir="$root/restore_$(date +%Y%m%d_%H%M%S)"
  if [[ "$dryrun" == "true" ]]; then
    backup_warn "Dryrun: would restore $full_path to $restore_dir (no files written)"
    return 0
  fi
  mkdir -p "$restore_dir"
  tar xzf "$full_path" -C "$restore_dir"
  backup_ok "Backup $(basename "$full_path") restored to $restore_dir"
}

recover_backup() {
  local backup_dir="$1" file="$2" root="$3" dryrun="${4:-false}"
  local full_path="$file"
  if [[ ! "$file" = /* ]] && [[ ! "$file" == ./* ]] && [[ ! "$file" == ../* ]]; then
    full_path="$backup_dir/$file"
  fi

  if [[ ! -f "$full_path" ]]; then
    backup_err "Backup file not found: $full_path"
    return 1
  fi

  if [[ "$dryrun" == "true" ]]; then
    backup_warn "Dryrun: would recover $full_path into $root (files would be overwritten!)"
    return 0
  fi

  read -rp "⚠️  This will OVERWRITE files in $root. Continue? (y/N): " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { backup_warn "Aborted"; return 1; }

  tar xzf "$full_path" -C "$root"
  backup_ok "Backup $(basename "$full_path") recovered into $root"
}

prune_backups() {
  local backup_dir="$1" N="$2" dryrun="${3:-false}"
  local files
  files=($(ls -1t "$backup_dir"/*.tar.gz 2>/dev/null))
  if ((${#files[@]} <= N)); then
    backup_info "Nothing to prune (total: ${#files[@]} <= $N)"
    return
  fi
  for i in "${files[@]:$N}"; do
    if [[ "$dryrun" == "true" ]]; then
      backup_warn "Dryrun: would prune $i"
    else
      rm -f "$i"
      backup_warn "Pruned $i"
    fi
  done
  if [[ "$dryrun" == "true" ]]; then
    backup_warn "Dryrun: would keep $N most recent backups (no files deleted)."
  else
    backup_ok "Prune complete. $N most recent backups kept."
  fi
}

# --- Git tag helpers ---
get_git_tag_info() {
  local root="$1"
  cd "$root" || return 1
  local tag commit parent
  tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "untagged")
  commit=$(git rev-parse HEAD)
  parent=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "none")
  echo "$tag" "$commit" "$parent"
}

get_sha256() {
  local file="$1"
  if command -v shasum &>/dev/null; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    sha256sum "$file" | awk '{print $1}'
  fi
}

add_log_md() {
  local mdfile="$1" date="$2" tag="$3" parent="$4" commit="$5" file="$6" size="$7" sha="$8" status="$9"
  echo "| $date | $tag | $parent | $commit | $file | $size | $sha | $status |" >>"$mdfile"
}

get_last_n_backups() {
  local mdfile="$1" N="$2"
  grep '^|' "$mdfile" | tail -n "$N"
}

write_log_md_from_tpl() {
  local tpl="$1" out="$2" summary_file="$3"
  awk -v summaryfile="$summary_file" '
    {
      if ($0 ~ /{{SUMMARY_ROWS}}/) {
        while ((getline l < summaryfile) > 0) print l
        next
      }
      print
    }
  ' "$tpl" >"$out"
}

# --- CLI exposed entrypoints ---
radar_backup_create()   { backup_project "$1" "$2" "$3" "$4" "$5" "$DRYRUN" "$7";}; 
radar_backup_restore()  { restore_backup "$3" "$1" "$2" "$DRYRUN"; }
radar_backup_recover()  { recover_backup "$3" "$1" "$2" "$DRYRUN"; }
radar_backup_prune()    { prune_backups "$1" "$2" "$DRYRUN"; }
radar_backup_summary()  { get_last_n_backups "$1" "$2"; }
