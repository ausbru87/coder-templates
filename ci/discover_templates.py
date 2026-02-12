#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from typing import List, Dict, Set


def git_diff_names(base_sha: str, head_sha: str) -> List[str]:
    cmd = ["git", "--no-pager", "diff", "--name-only", f"{base_sha}...{head_sha}"]
    out = subprocess.check_output(cmd, text=True).strip()
    return [line.strip() for line in out.splitlines() if line.strip()]


def parse_template_path(deployment_dir: str, changed_path: str) -> str:
    deployment_dir = os.path.normpath(deployment_dir)
    changed_path = os.path.normpath(changed_path)

    if changed_path == deployment_dir or not changed_path.startswith(deployment_dir + os.sep):
      return ""

    rel = os.path.relpath(changed_path, deployment_dir)
    parts = rel.split(os.sep)
    if len(parts) < 2:
        return ""

    template_dir = os.path.join(deployment_dir, parts[0])
    if os.path.isdir(template_dir):
        return os.path.normpath(template_dir)
    return ""


def list_all_templates(deployment_dir: str) -> List[str]:
    items: List[str] = []
    for entry in sorted(os.listdir(deployment_dir)):
        path = os.path.join(deployment_dir, entry)
        if os.path.isdir(path):
            items.append(os.path.normpath(path))
    return items


def discover_templates(deployment_dir: str, base_sha: str, head_sha: str) -> List[str]:
    changed = git_diff_names(base_sha, head_sha)
    templates: Set[str] = set()

    for path in changed:
        template_dir = parse_template_path(deployment_dir, path)
        if template_dir:
            templates.add(template_dir)

    return sorted(templates)


def to_matrix(template_dirs: List[str]) -> Dict[str, List[Dict[str, str]]]:
    return {
        "include": [
            {
                "template": os.path.basename(path),
                "dir": path,
            }
            for path in template_dirs
        ]
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Discover changed template directories")
    parser.add_argument("--deployment-dir", required=True)
    parser.add_argument("--list-all", action="store_true")
    parser.add_argument("--base")
    parser.add_argument("--head")
    parser.add_argument("--json-output", default="")
    parser.add_argument("--text-output", default="")
    args = parser.parse_args()

    deployment_dir = os.path.normpath(args.deployment_dir)
    if not os.path.isdir(deployment_dir):
        print(f"Deployment directory not found: {deployment_dir}", file=sys.stderr)
        return 1

    if args.list_all:
        template_dirs = list_all_templates(deployment_dir)
    else:
        if not args.base or not args.head:
            print("--base and --head are required unless --list-all is set", file=sys.stderr)
            return 1
        template_dirs = discover_templates(deployment_dir, args.base, args.head)

    matrix = to_matrix(template_dirs)
    matrix_json = json.dumps(matrix)

    print(matrix_json)

    if args.json_output:
        with open(args.json_output, "w", encoding="utf-8") as f:
            f.write(matrix_json)

    if args.text_output:
        with open(args.text_output, "w", encoding="utf-8") as f:
            for path in template_dirs:
                f.write(path + "\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
