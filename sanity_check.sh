#!/opt/homebrew/bin/bash
set -euo pipefail

VERSION="1.0.4"

print_version() {
  local tool="$1"; shift
  if ! command -v "$tool" &>/dev/null; then
    echo -e "⚠️  $tool: \033[1;33mnot installed\033[0m"
    return
  fi
  # Try common version flags, fall back to subcommands if needed
  local out=""
  for flag in --version version -v "-V"; do
    out="$("$tool" $flag 2>&1 | grep -iE 'version|[0-9]+\.[0-9]+' | head -n 1)" && [[ -n "$out" ]] && break
  done
  # Some tools only report with subcommands (e.g. terraform version, dockerfmt version)
  if [[ -z "$out" && "$tool" =~ ^(terraform|dockerfmt|syft|grype|trivy)$ ]]; then
    out="$("$tool" version 2>&1 | grep -iE 'version|[0-9]+\.[0-9]+' | head -n 1)"
  fi
  if [[ -z "$out" ]]; then
    echo -e "⚠️  $tool: \033[1;33mversion unknown (tool present, version flag not recognized)\033[0m"
  else
    echo "$tool: $out"
  fi
}

if [[ "${1:-}" == "--help" ]]; then
  cat <<EOF
sanity_check.sh [OPTIONS] <file1> [file2 ...]
Run formatters and linters for supported scripts. Generates markdown reports as needed.

Supported extensions: .sh, .py, .js, .tf, Dockerfile

Options:
  --fix            Format all provided files (default: all = format+lint)
  --lint           Lint all provided files only
  --all            Run both formatters and linters (default)
  --summary        Output only summary results
  --quiet          Silence output except errors
  --report         Append/refresh markdown report (sanity_check.md)
  --fresh-report   Create new markdown report (overwrites previous)
  --check-tools    Validate required tooling is installed
  --version        Show formatter and linter versions
  --help           Show this help message

Examples:
  ./sanity_check.sh --fix myscript.sh
  ./sanity_check.sh --lint *.sh
  ./sanity_check.sh --report main.py
  ./sanity_check.sh --quiet myscript.sh

EOF
  exit 0
fi

declare -A FORMATTERS=(
  [sh]="shfmt -w -i 2"
  [py]="black"
  [js]="prettier --write"
  [tf]="terraform fmt -recursive"
  [Dockerfile]="dockerfmt -w"
)

declare -A LINTERS=(
  [sh]="shellcheck -x"
  [py]="pylint"
  [js]="eslint"
  [tf]="terraform validate"
  [Dockerfile]="hadolint"
)

SUPPORTED_EXTENSIONS=(sh py js tf Dockerfile)
MISSING_TOOL_WARNINGS=()

# 🛠️ Default settings
MODE="all"
FILES=()
PROBLEM_FILES=()
REPORT=false
QUIET=false
SUMMARY=false

# 🎛️ Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  --fix) MODE="fix"; shift ;;
  --lint) MODE="lint"; shift ;;
  --all) MODE="all"; shift ;;
  --summary) SUMMARY=true; shift ;;
  --report) REPORT=true; shift ;;
  --quiet) QUIET=true; shift ;;
  --fresh-report) echo "🧼 Fresh report started on $(date)" >sanity_check.md; shift ;;
  --check-tools)
    echo "🔍 Validating tool availability..."
    for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
      echo "- $ext:"
      SEEN_TOOLS=()
      for tool in "${FORMATTERS[$ext]}" "${LINTERS[$ext]}"; do
        TOOL_CMD="${tool%% *}"
        if [[ ! " ${SEEN_TOOLS[*]} " =~ " ${TOOL_CMD} " ]]; then
          SEEN_TOOLS+=("$TOOL_CMD")
          echo -n "  $TOOL_CMD: "
          if command -v "$TOOL_CMD" >/dev/null 2>&1; then
            echo "✅ found"
          else
            echo "❌ missing"
          fi
        fi
      done
    done
    exit 0
    ;;
    --version)
    echo "🧪 Tool Versions:"
    # Tool groups: label:(tools...)
    declare -A TOOL_GROUPS=(
      [Bash]="shfmt shellcheck"
      [Python]="black pylint"
      [Node]="prettier eslint"
      [Terraform]="terraform"
      [Docker]="dockerfmt hadolint"
      [ContainerSecurity]="trivy syft grype"
    )
    for GROUP in "${!TOOL_GROUPS[@]}"; do
      echo -e "\n🔹 \033[1;36m$GROUP\033[0m"
      for tool in ${TOOL_GROUPS[$GROUP]}; do
        if command -v "$tool" &>/dev/null; then
          out=""
          for flag in --version version -v "-V"; do
            out="$("$tool" $flag 2>&1 | grep -iE 'version|[0-9]+\.[0-9]+' | head -n 1)" && [[ -n "$out" ]] && break
          done
          if [[ -z "$out" && "$tool" =~ ^(terraform|dockerfmt|syft|grype|trivy)$ ]]; then
            out="$("$tool" version 2>&1 | grep -iE 'version|[0-9]+' | head -n 1)"
          fi
          [[ -z "$out" ]] && out="version unknown (tool present, flag not recognized)"
          echo -e "  ✅ $tool: $out"
        else
          echo -e "  ⚠️  $tool: \033[1;33mnot installed\033[0m"
        fi
      done
    done
    exit 0
    ;;
  -* | --*)
    echo "❌ Unknown option: $1"
    exit 1
    ;;
  *)
    FILES+=("$1")
    shift
    ;;
  esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "❌ No files provided."
  exit 1
fi

# 🚀 Process each file
for SCRIPT in "${FILES[@]}"; do
  BASENAME="$(basename "$SCRIPT")"
  EXT="${BASENAME##*.}"
  EXT="${EXT,,}"
  [[ "$BASENAME" == "Dockerfile" ]] && EXT="Dockerfile"

  if [[ ! " ${SUPPORTED_EXTENSIONS[*]} " =~ " $EXT " ]]; then
    [[ "$QUIET" == false ]] && echo "⚠️ Skipping unsupported file: $SCRIPT"
    continue
  fi

  FORMATTER="${FORMATTERS[$EXT]:-}"
  LINTER="${LINTERS[$EXT]:-}"

  [[ "$QUIET" == false ]] && echo -e "\n🎯 Processing: $SCRIPT"

  if [[ "$MODE" == "fix" || "$MODE" == "all" ]]; then
    if [[ -n "$FORMATTER" ]]; then
      TOOL="${FORMATTER%% *}"
      if command -v "$TOOL" >/dev/null 2>&1; then
        [[ "$QUIET" == false ]] && echo "🎨 Formatting $SCRIPT with $FORMATTER..."
        $FORMATTER "$SCRIPT" &>/dev/null || true
      else
        MISSING_TOOL_WARNINGS+=("$TOOL (required to format $SCRIPT)")
      fi
    fi
  fi

  if [[ "$MODE" == "lint" || "$MODE" == "all" || "$SUMMARY" == true ]]; then
    if [[ -n "$LINTER" ]]; then
      TOOL="${LINTER%% *}"
      if command -v "$TOOL" >/dev/null 2>&1; then
        [[ "$QUIET" == false ]] && echo "🔍 Linting $SCRIPT with $LINTER..."
        if ! $LINTER "$SCRIPT"; then
          PROBLEM_FILES+=("$SCRIPT")
        fi
      else
        MISSING_TOOL_WARNINGS+=("$TOOL (required to lint $SCRIPT)")
      fi
    fi
  fi
done

# 🔇 Quiet mode result output
if [[ "$QUIET" == true ]]; then
  if [[ ${#PROBLEM_FILES[@]} -eq 0 ]]; then
    echo -e "\n✅ All checks completed (no issues found)."
  else
    echo -e "\n⚠️  Lint issues were found in the following files:"
    for file in "${PROBLEM_FILES[@]}"; do echo " - $file"; done
    exit 1
  fi
  exit 0
fi

# 📊 Summary output
if [[ "$SUMMARY" == true ]]; then
  if [[ ${#PROBLEM_FILES[@]} -gt 0 ]]; then
    echo -e "\n⚠️  \033[1;31mLint issues were found in the following files:\033[0m"
    for file in "${PROBLEM_FILES[@]}"; do echo -e " - \033[1;33m$file\033[0m"; done
    exit 1
  else
    echo -e "\n✅ All scripts passed lint checks."
    exit 0
  fi
fi

# ✅ Final status
if [[ ${#MISSING_TOOL_WARNINGS[@]} -gt 0 ]]; then
  echo -e "\n⚠️  Some tools were missing:"
  for warn in "${MISSING_TOOL_WARNINGS[@]}"; do echo " - $warn"; done
fi

if [[ ${#PROBLEM_FILES[@]} -gt 0 ]]; then
  echo -e "\n⚠️  One or more issues were found. Please review the output above."
else
  echo -e "\n✅ All checks completed."
fi

# 🧾 Markdown report (auto-generated on --report OR missing tools/issues)
if [[ "$REPORT" == true || ${#MISSING_TOOL_WARNINGS[@]} -gt 0 || ${#PROBLEM_FILES[@]} -gt 0 ]]; then
  REPORT_FILE="sanity_check.md"
  {
    echo ""
    echo "---"
    echo "## 🕒 Report: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    if [[ ${#FILES[@]} -gt 0 ]]; then
      echo "### 📂 Processed Files"
      for file in "${FILES[@]}"; do echo "- \`$file\`"; done
      echo ""
    fi

    if [[ ${#MISSING_TOOL_WARNINGS[@]} -gt 0 ]]; then
      echo "### ⚠️ Missing Tools"
      for warn in "${MISSING_TOOL_WARNINGS[@]}"; do echo "- $warn"; done
      echo ""
    fi

    if [[ ${#PROBLEM_FILES[@]} -eq 0 ]]; then
      echo "### ✅ No lint issues found."
    else
      echo "### ❗ Lint Issues Found"
      for file in "${PROBLEM_FILES[@]}"; do echo "- \`$file\`"; done
    fi
  } >>"$REPORT_FILE"

  echo -e "\n📄 Markdown report saved to \033[1;36m$REPORT_FILE\033[0m"
fi
