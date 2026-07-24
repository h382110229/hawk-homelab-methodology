#!/usr/bin/env bash
#
# hawk-homelab installer — Download and install create-hawk-homelab CLI
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash -s -- my-project --port 8080
#
# Compatible with bash 3.2+ (macOS default)

set -e

REPO_URL="https://github.com/hawk-homelab/hawk-homelab-methodology"
INSTALL_DIR="${HAWK_HOME:-$HOME/.hawk-homelab}"

# --- Colors ---
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  RED='\033[0;31m'
  NC='\033[0m'
else
  GREEN=''
  BLUE=''
  RED=''
  NC=''
fi

echo "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo "${BLUE}║   hawk-homelab — Installer               ║${NC}"
echo "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# --- Check dependencies ---
check_deps() {
  if ! command -v git >/dev/null 2>&1; then
    echo "${RED}Error: git is required but not installed.${NC}" >&2
    exit 1
  fi
}

# --- Clone or update repo ---
install_repo() {
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Updating existing installation at $INSTALL_DIR..."
    cd "$INSTALL_DIR"
    git pull --quiet 2>/dev/null || true
  else
    echo "Installing to $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null
  fi
}

# --- Create symlink for easy access ---
link_binary() {
  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"

  if [ -d "$bin_dir" ]; then
    ln -sf "$INSTALL_DIR/cli/shell/init.sh" "$bin_dir/create-hawk-homelab"
    chmod +x "$INSTALL_DIR/cli/shell/init.sh"
    echo "${GREEN}✅ Linked to $bin_dir/create-hawk-homelab${NC}"
    echo ""
    echo "Make sure $bin_dir is in your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
}

# --- Main ---
check_deps
install_repo
link_binary

echo ""
echo "${GREEN}✅ Installation complete!${NC}"
echo ""
echo "Usage:"
echo "  bash $INSTALL_DIR/cli/shell/init.sh my-project --port 8080"
echo "  # or if linked:"
echo "  create-hawk-homelab my-project --port 8080"
echo ""
echo "Run without arguments for interactive mode:"
echo "  bash $INSTALL_DIR/cli/shell/init.sh"
echo ""

# If arguments were passed (e.g., via curl | bash -s -- my-project --port 8080),
# run init.sh with those arguments
if [ $# -gt 0 ]; then
  echo "Running init with provided arguments..."
  bash "$INSTALL_DIR/cli/shell/init.sh" "$@"
fi
