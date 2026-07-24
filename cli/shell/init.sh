#!/usr/bin/env bash
#
# hawk-homelab init — Scaffold a new homelab project
#
# Usage:
#   ./init.sh <project-name> [options]
#   ./init.sh                    # interactive mode
#
# Options:
#   --port <port>              External port (default: 8080)
#   --internal-port <port>     Internal port (default: 8080)
#   --image <image>            Docker image (default: nginx)
#   --version <version>        Image version (default: latest)
#   --description <desc>       Project description
#
# Compatible with bash 3.2+ (macOS default)

set -e

# --- Resolve script directory (works even when symlinked) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/../../templates" && pwd)"

# --- Defaults ---
PROJECT_NAME=""
PORT="8080"
INTERNAL_PORT="8080"
IMAGE="nginx"
VERSION="latest"
PROJECT_DESCRIPTION="A homelab service managed by Hawk methodology"

# --- Colors (if terminal supports them) ---
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  NC='\033[0m'
else
  GREEN=''
  BLUE=''
  YELLOW=''
  RED=''
  NC=''
fi

# --- Parse arguments ---
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --port)
        PORT="$2"; shift 2 ;;
      --internal-port)
        INTERNAL_PORT="$2"; shift 2 ;;
      --image)
        IMAGE="$2"; shift 2 ;;
      --version)
        VERSION="$2"; shift 2 ;;
      --description)
        PROJECT_DESCRIPTION="$2"; shift 2 ;;
      -*)
        echo "${RED}Unknown option: $1${NC}" >&2
        exit 1 ;;
      *)
        if [ -z "$PROJECT_NAME" ]; then
          PROJECT_NAME="$1"
        else
          echo "${RED}Unexpected argument: $1${NC}" >&2
          exit 1
        fi
        shift ;;
    esac
  done
}

# --- Interactive prompts ---
prompt_with_default() {
  local prompt="$1"
  local default="$2"
  local varname="$3"
  local value

  printf "%s [%s]: " "$prompt" "$default"
  read -r value
  if [ -z "$value" ]; then
    value="$default"
  fi

  eval "$varname=\"\$value\""
}

interactive_mode() {
  echo ""
  echo "${BLUE}╔══════════════════════════════════════════╗${NC}"
  echo "${BLUE}║   hawk-homelab — Project Initializer     ║${NC}"
  echo "${BLUE}╚══════════════════════════════════════════╝${NC}"
  echo ""

  prompt_with_default "Project name" "my-project" "PROJECT_NAME"
  prompt_with_default "External port" "$PORT" "PORT"
  prompt_with_default "Internal port" "$INTERNAL_PORT" "INTERNAL_PORT"
  prompt_with_default "Docker image" "$IMAGE" "IMAGE"
  prompt_with_default "Image version" "$VERSION" "VERSION"
  prompt_with_default "Project description" "$PROJECT_DESCRIPTION" "PROJECT_DESCRIPTION"

  echo ""
}

# --- Replace placeholders in a single file ---
replace_placeholders() {
  local file="$1"

  # Use perl for portability (available on macOS by default)
  # Process in-place with all known placeholders
  perl -pi -e "
    s/\{\{PROJECT_NAME\}\}/$PROJECT_NAME/g;
    s/\{\{PORT\}\}/$PORT/g;
    s/\{\{INTERNAL_PORT\}\}/$INTERNAL_PORT/g;
    s/\{\{IMAGE\}\}/$IMAGE/g;
    s/\{\{VERSION\}\}/$VERSION/g;
    s/\{\{PROJECT_DESCRIPTION\}\}/$PROJECT_DESCRIPTION/g;
    s/\{\{SERVICE_DESCRIPTION\}\}/$PROJECT_DESCRIPTION/g;
    s/\{\{DATE\}\}/$(date +%Y-%m-%d)/g;
  " "$file"
}

# --- Recursively replace placeholders in all files ---
replace_all() {
  local dir="$1"
  local file

  # Use find + while loop (bash 3.2 compatible, handles spaces in names)
  find "$dir" -type f | while IFS= read -r file; do
    replace_placeholders "$file"
  done
}

# --- Make scripts executable ---
make_executable() {
  local dir="$1"

  find "$dir" -type f -name "*.sh" | while IFS= read -r file; do
    chmod +x "$file"
  done
}

# --- Print directory tree (bash 3.2 compatible, no 'tree' dependency) ---
print_tree() {
  local dir="$1"
  local prefix="$2"
  local entries=""
  local entry=""
  local count=0
  local i=0

  # Collect entries (files and dirs)
  entries=$(ls -1A "$dir" 2>/dev/null)
  count=$(echo "$entries" | wc -l | tr -d ' ')

  for entry in $entries; do
    i=$((i + 1))
    local path="$dir/$entry"
    local connector="├── "
    local next_prefix="${prefix}│   "

    if [ "$i" -eq "$count" ]; then
      connector="└── "
      next_prefix="${prefix}    "
    fi

    if [ -d "$path" ]; then
      echo "${prefix}${connector}${entry}/"
      print_tree "$path" "$next_prefix"
    else
      echo "${prefix}${connector}${entry}"
    fi
  done
}

# --- Main ---
parse_args "$@"

# If no project name provided, enter interactive mode
if [ -z "$PROJECT_NAME" ]; then
  interactive_mode
fi

# Validate project name
if [ -z "$PROJECT_NAME" ]; then
  echo "${RED}Error: Project name is required.${NC}" >&2
  exit 1
fi

# Check if target directory already exists
if [ -d "$PROJECT_NAME" ]; then
  echo "${RED}Error: Directory '$PROJECT_NAME' already exists.${NC}" >&2
  exit 1
fi

# Check that template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "${RED}Error: Templates directory not found at $TEMPLATE_DIR${NC}" >&2
  exit 1
fi

echo ""
echo "${BLUE}Creating project: ${PROJECT_NAME}${NC}"
echo "  Image:  ${IMAGE}:${VERSION}"
echo "  Port:   ${PORT} → ${INTERNAL_PORT}"
echo ""

# Step 1: Copy templates
cp -R "$TEMPLATE_DIR" "$PROJECT_NAME"

# Step 2: Replace placeholders
replace_all "$PROJECT_NAME"

# Step 3: Make scripts executable
make_executable "$PROJECT_NAME"

# Step 4: Print success
echo "${GREEN}✅ Project '${PROJECT_NAME}' created successfully!${NC}"
echo ""
echo "Directory structure:"
echo "${PROJECT_NAME}/"
print_tree "$PROJECT_NAME" ""

echo ""
echo "${YELLOW}Next steps:${NC}"
echo "  cd ${PROJECT_NAME}"
echo "  # Edit docker-compose.yml and other configs as needed"
echo "  bash deploy.sh"
echo ""
