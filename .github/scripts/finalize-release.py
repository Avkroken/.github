#!/usr/bin/env python3
"""Finalize draft release notes without executing caller repository code."""

from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path

DEPENDENCY_PATTERN = re.compile(
    r"^(?:(?:chore|build)\((?:deps|deps-dev)\):|deps(?:\([^)]*\))?:)",
    re.IGNORECASE,
)
MAX_DEPENDENCIES = 20
MAX_COMPONENTS = 12


def dependency_updates(compare: dict) -> list[str]:
    updates: list[str] = []
    for commit in compare.get("commits", []):
        subject = commit.get("commit", {}).get("message", "").splitlines()[0].strip()
        if subject and DEPENDENCY_PATTERN.match(subject) and subject not in updates:
            updates.append(subject)
    return updates


def nested_value(data: object, key: str) -> object:
    value = data
    for part in key.split("."):
        if not isinstance(value, dict) or part not in value:
            raise ValueError(f"missing version key: {key}")
        value = value[part]
    return value


def safe_component_path(root: Path, raw_path: str) -> Path:
    rel = Path(raw_path)
    if not raw_path or rel.is_absolute():
        raise ValueError("component path must be repository-relative")
    candidate = (root / rel).resolve()
    if root != candidate and root not in candidate.parents:
        raise ValueError("component path escapes repository root")
    if not candidate.is_file():
        raise ValueError(f"component file does not exist: {raw_path}")
    return candidate


def component_rows(config_path: Path, root: Path, release_tag: str) -> list[tuple[str, str]]:
    if not config_path.is_file():
        return []

    config = json.loads(config_path.read_text())
    components = config.get("components", [])
    if not isinstance(components, list) or len(components) > MAX_COMPONENTS:
        raise ValueError(f"components must be a list with at most {MAX_COMPONENTS} entries")

    rows: list[tuple[str, str]] = []
    for item in components:
        if not isinstance(item, dict):
            raise ValueError("invalid component entry")

        name = str(item.get("name", "")).strip()
        source = item.get("source")
        if not name or len(name) > 80:
            raise ValueError("component name must be 1-80 characters")

        if source == "release":
            version: object = release_tag
        elif source in {"json", "toml"}:
            candidate = safe_component_path(root, str(item.get("path", "")))
            key = str(item.get("key", "")).strip()
            if not key:
                raise ValueError(f"missing component key for {name}")
            if source == "json":
                data = json.loads(candidate.read_text())
            else:
                with candidate.open("rb") as handle:
                    data = tomllib.load(handle)
            version = nested_value(data, key)
        else:
            raise ValueError(f"unsupported component source for {name}")

        version_text = str(version).strip()
        if not version_text or len(version_text) > 80 or "\n" in version_text:
            raise ValueError(f"invalid version for {name}")
        rows.append((name.replace("|", "\\|"), version_text.replace("|", "\\|")))

    return rows


def render(body: str, compare: dict, rows: list[tuple[str, str]]) -> str:
    sections: list[str] = []

    dependencies = dependency_updates(compare)
    if dependencies:
        visible = dependencies[:MAX_DEPENDENCIES]
        lines = ["## Dependency updates", ""] + [f"- {line}" for line in visible]
        if len(dependencies) > len(visible):
            lines.append(f"- … and {len(dependencies) - len(visible)} more dependency updates")
        sections.append("\n".join(lines))

    if rows:
        lines = ["## Program versions", "", "| Program | Version |", "| --- | --- |"]
        lines.extend(f"| {name} | {version} |" for name, version in rows)
        sections.append("\n".join(lines))

    final = body.rstrip()
    if sections:
        final += "\n\n" + "\n\n".join(sections)
    return final.rstrip() + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--body", required=True, type=Path)
    parser.add_argument("--compare", required=True, type=Path)
    parser.add_argument("--components", required=True, type=Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--repo-root", default=Path.cwd(), type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.repo_root.resolve()
    compare = json.loads(args.compare.read_text())
    rows = component_rows(args.components, root, args.tag)
    args.output.write_text(render(args.body.read_text(), compare, rows))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, json.JSONDecodeError, OSError) as exc:
        print(f"release note finalization failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
