"""CLI entry point for hawk-homelab."""

import argparse
import sys

from hawk_homelab import __version__
from hawk_homelab.init import scaffold


def main(argv=None):
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        prog="hawk-homelab",
        description="Scaffold a new homelab project using the Hawk methodology",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")

    subparsers = parser.add_subparsers(dest="command")

    # `init` subcommand
    init_parser = subparsers.add_parser("init", help="Initialize a new homelab project")
    init_parser.add_argument("project_name", nargs="?", default="", help="Project name")
    init_parser.add_argument("--port", default="8080", help="External port (default: 8080)")
    init_parser.add_argument("--internal-port", default="8080", help="Internal port (default: 8080)")
    init_parser.add_argument("--image", default="nginx", help="Docker image (default: nginx)")
    init_parser.add_argument("--version", dest="img_version", default="latest", help="Image version (default: latest)")
    init_parser.add_argument("--description", default="A homelab service managed by Hawk methodology", help="Project description")

    args = parser.parse_args(argv)

    if not args.command:
        parser.print_help()
        sys.exit(1)

    if args.command == "init":
        scaffold(
            project_name=args.project_name,
            port=args.port,
            internal_port=args.internal_port,
            image=args.image,
            version=args.img_version,
            description=args.description,
        )


if __name__ == "__main__":
    main()
