"""Init logic — copy templates, replace placeholders."""

import os
import re
import shutil
import sys
from datetime import date
from pathlib import Path


# Path to templates directory (relative to repo root)
TEMPLATE_DIR = Path(__file__).resolve().parent.parent.parent.parent / "templates"

# ANSI colors
IS_TTY = sys.stdout.isatty()
GREEN = "\033[0;32m" if IS_TTY else ""
BLUE = "\033[0;34m" if IS_TTY else ""
YELLOW = "\033[1;33m" if IS_TTY else ""
RED = "\033[0;31m" if IS_TTY else ""
NC = "\033[0m" if IS_TTY else ""

# Defaults
DEFAULTS = {
    "port": "8080",
    "internal_port": "8080",
    "image": "nginx",
    "version": "latest",
    "description": "A homelab service managed by Hawk methodology",
}


def prompt_with_default(question: str, default: str) -> str:
    """Prompt user with a default value."""
    try:
        answer = input(f"{question} [{default}]: ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(1)
    return answer if answer else default


def interactive_mode(project_name: str, port: str, internal_port: str,
                     image: str, version: str, description: str) -> dict:
    """Run interactive prompts to collect parameters."""
    print()
    print(f"{BLUE}╔══════════════════════════════════════════╗{NC}")
    print(f"{BLUE}║   hawk-homelab — Project Initializer     ║{NC}")
    print(f"{BLUE}╚══════════════════════════════════════════╝{NC}")
    print()

    return {
        "project_name": prompt_with_default("Project name", project_name or "my-project"),
        "port": prompt_with_default("External port", port),
        "internal_port": prompt_with_default("Internal port", internal_port),
        "image": prompt_with_default("Docker image", image),
        "version": prompt_with_default("Image version", version),
        "description": prompt_with_default("Project description", description),
    }


def replace_placeholders(content: str, vars: dict) -> str:
    """Replace all {{PLACEHOLDER}} values in content."""
    today = date.today().isoformat()

    content = content.replace("{{PROJECT_NAME}}", vars["project_name"])
    content = content.replace("{{PORT}}", vars["port"])
    content = content.replace("{{INTERNAL_PORT}}", vars["internal_port"])
    content = content.replace("{{IMAGE}}", vars["image"])
    content = content.replace("{{VERSION}}", vars["version"])
    content = content.replace("{{PROJECT_DESCRIPTION}}", vars["description"])
    content = content.replace("{{SERVICE_DESCRIPTION}}", vars["description"])
    content = content.replace("{{DB_USER}}", "postgres")
    content = content.replace("{{DATE}}", today)

    return content


def replace_all(target_dir: Path, vars: dict) -> None:
    """Recursively replace placeholders in all files."""
    for file_path in target_dir.rglob("*"):
        if file_path.is_file():
            try:
                content = file_path.read_text(encoding="utf-8")
                new_content = replace_placeholders(content, vars)
                if new_content != content:
                    file_path.write_text(new_content, encoding="utf-8")
            except (UnicodeDecodeError, PermissionError):
                # Skip binary files or unreadable files
                pass


def make_executable(target_dir: Path) -> None:
    """Make all .sh files executable."""
    for file_path in target_dir.rglob("*.sh"):
        file_path.chmod(file_path.stat().st_mode | 0o755)


def print_tree(directory: Path, prefix: str = "") -> None:
    """Print directory tree (no external dependencies)."""
    entries = sorted(directory.iterdir())
    count = len(entries)

    for i, entry in enumerate(entries):
        is_last = i == count - 1
        connector = "└── " if is_last else "├── "
        next_prefix = prefix + ("    " if is_last else "│   ")

        if entry.is_dir():
            print(f"{prefix}{connector}{entry.name}/")
            print_tree(entry, next_prefix)
        else:
            print(f"{prefix}{connector}{entry.name}")


def scaffold(project_name: str = "", port: str = "8080",
             internal_port: str = "8080", image: str = "nginx",
             version: str = "latest", description: str = "A homelab service managed by Hawk methodology") -> None:
    """Main scaffold function — copy templates and replace placeholders."""

    # If no project name, enter interactive mode
    if not project_name:
        params = interactive_mode(project_name, port, internal_port, image, version, description)
    else:
        params = {
            "project_name": project_name,
            "port": port,
            "internal_port": internal_port,
            "image": image,
            "version": version,
            "description": description,
        }

    # Validate
    if not params["project_name"]:
        print(f"{RED}Error: Project name is required.{NC}", file=sys.stderr)
        sys.exit(1)

    target_dir = Path.cwd() / params["project_name"]

    if target_dir.exists():
        print(f"{RED}Error: Directory '{params['project_name']}' already exists.{NC}", file=sys.stderr)
        sys.exit(1)

    if not TEMPLATE_DIR.exists():
        print(f"{RED}Error: Templates directory not found at {TEMPLATE_DIR}{NC}", file=sys.stderr)
        sys.exit(1)

    print()
    print(f"{BLUE}Creating project: {params['project_name']}{NC}")
    print(f"  Image:  {params['image']}:{params['version']}")
    print(f"  Port:   {params['port']} → {params['internal_port']}")
    print()

    # Step 1: Copy templates
    shutil.copytree(str(TEMPLATE_DIR), str(target_dir))

    # Step 2: Replace placeholders
    replace_all(target_dir, params)

    # Step 3: Make scripts executable
    make_executable(target_dir)

    # Step 4: Print success
    print(f"{GREEN}✅ Project '{params['project_name']}' created successfully!{NC}")
    print()
    print("Directory structure:")
    print(f"{params['project_name']}/")
    print_tree(target_dir)

    print()
    print(f"{YELLOW}Next steps:{NC}")
    print(f"  cd {params['project_name']}")
    print("  # Edit docker-compose.yml and other configs as needed")
    print("  bash deploy.sh")
    print()
