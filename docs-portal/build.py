#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import posixpath
import re
import shutil
import subprocess
import tempfile
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

ROOT_DOCS = {
    "README.md",
    "SECURITY.md",
    "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md",
    "SUPPORT.md",
}

LINK_RE = re.compile(r'(?P<prefix>!?\[[^\]]*\]\()(?P<target>[^)]+)(?P<suffix>\))')
ENDRAW_RE = re.compile(r"{%-?\s*endraw\s*-?%}", re.IGNORECASE)


def get_json(url: str):
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "avkroken-docs-mirror/1",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def discover(org: str):
    repos, page = [], 1
    while True:
        batch = get_json(
            f"https://api.github.com/orgs/{org}/repos"
            f"?type=public&per_page=100&page={page}"
        )
        if not batch:
            break
        repos.extend(batch)
        if len(batch) < 100:
            break
        page += 1

    return sorted(
        [
            repo
            for repo in repos
            if not repo.get("archived")
            and not repo.get("fork")
            and repo.get("visibility") == "public"
            and repo.get("name") != ".github"
        ],
        key=lambda repo: repo["name"].lower(),
    )


def clone(url: str, dest: Path, branch: str | None = None) -> bool:
    cmd = ["git", "clone", "--depth", "1"]
    if branch:
        cmd += ["--branch", branch]
    cmd += [url, str(dest)]
    return subprocess.run(cmd, text=True, capture_output=True).returncode == 0


def documentation_file(path: Path, root: Path) -> bool:
    if path.is_symlink():
        return False
    rel = path.relative_to(root)
    if ".git" in rel.parts or ".github" in rel.parts:
        return False
    if rel.as_posix().startswith("docs/"):
        return True
    if path.name in ROOT_DOCS:
        return True
    return path.name.lower() == "readme.md"


def split_link_target(target: str):
    stripped = target.strip()
    if stripped.startswith("<") and ">" in stripped:
        close = stripped.index(">")
        return stripped[1:close], stripped[close + 1 :]
    match = re.match(r"^(\S+)(.*)$", stripped, re.DOTALL)
    if not match:
        return stripped, ""
    return match.group(1), match.group(2)


def rewrite_repo_links(
    text: str,
    *,
    org: str,
    repo: str,
    branch: str,
    current_rel: str,
    mirrored_files: set[str],
):
    current_dir = posixpath.dirname(current_rel) or "."

    def replace(match):
        prefix = match.group("prefix")
        raw_target = match.group("target")
        suffix = match.group("suffix")
        target, title = split_link_target(raw_target)

        if (
            not target
            or target.startswith("#")
            or target.startswith("/")
            or target.startswith("http://")
            or target.startswith("https://")
            or target.startswith("mailto:")
            or target.startswith("tel:")
            or "{{" in target
            or "}}" in target
        ):
            return match.group(0)

        parts = urlsplit(target)
        if parts.scheme or parts.netloc:
            return match.group(0)

        resolved = posixpath.normpath(posixpath.join(current_dir, parts.path))
        if resolved.startswith("../"):
            return match.group(0)

        is_image = prefix.startswith("![")
        is_mirrored_file = resolved in mirrored_files
        is_mirrored_dir = any(
            path.startswith(resolved.rstrip("/") + "/") for path in mirrored_files
        )

        if is_mirrored_file:
            mirror_target = resolved
            if mirror_target.lower().endswith(".md"):
                mirror_target = mirror_target[:-3] + ".html"
            relative = posixpath.relpath(mirror_target, current_dir)
            new_target = urlunsplit(parts._replace(path=relative))
        elif is_mirrored_dir:
            new_target = (
                f"https://github.com/{org}/{repo}/tree/{branch}/{resolved.rstrip('/')}"
            )
            if parts.fragment:
                new_target += f"#{parts.fragment}"
        else:
            if is_image:
                new_target = (
                    f"https://raw.githubusercontent.com/{org}/{repo}/{branch}/{resolved}"
                )
            else:
                new_target = (
                    f"https://github.com/{org}/{repo}/blob/{branch}/{resolved}"
                )
            if parts.query:
                new_target += f"?{parts.query}"
            if parts.fragment:
                new_target += f"#{parts.fragment}"

        return f"{prefix}{new_target}{title}{suffix}"

    return LINK_RE.sub(replace, text)


def rewrite_wiki_links(text: str, wiki_files: set[str], current_rel: str):
    current_dir = posixpath.dirname(current_rel) or "."

    def replace(match):
        prefix = match.group("prefix")
        raw_target = match.group("target")
        suffix = match.group("suffix")
        target, title = split_link_target(raw_target)

        if (
            not target
            or target.startswith("#")
            or target.startswith("/")
            or target.startswith("http://")
            or target.startswith("https://")
            or target.startswith("mailto:")
            or "{{" in target
            or "}}" in target
        ):
            return match.group(0)

        parts = urlsplit(target)
        resolved = posixpath.normpath(posixpath.join(current_dir, parts.path))
        candidates = [resolved]
        if not resolved.lower().endswith(".md"):
            candidates.append(resolved + ".md")

        selected = next((path for path in candidates if path in wiki_files), None)
        if not selected:
            return match.group(0)

        mirror_target = selected[:-3] + ".html"
        relative = posixpath.relpath(mirror_target, current_dir)
        new_target = urlunsplit(parts._replace(path=relative))
        return f"{prefix}{new_target}{title}{suffix}"

    return LINK_RE.sub(replace, text)


def frontmatter(title: str, canonical: str, body: str) -> str:
    title = title.replace('"', '\\"')
    body = ENDRAW_RE.sub(
        "{% endraw %}{{ '{% endraw %}' }}{% raw %}",
        body,
    )
    return (
        "---\n"
        "layout: default\n"
        f'title: "{title}"\n'
        "---\n\n"
        f"> **Automatisk spegel.** Canonical källa: "
        f"[{canonical}]({canonical}). Ändringar ska göras där.\n\n"
        + "{% raw %}\n"
        + body
        + "\n{% endraw %}\n"
    )


def write_site_shell(out: Path):
    (out / "_layouts").mkdir(parents=True)
    (out / "assets").mkdir(parents=True)

    (out / "_layouts" / "default.html").write_text(
        """<!doctype html>
<html lang="sv">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{ page.title | escape }} · Avkroken</title>
<link rel="stylesheet" href="{{ '/assets/style.css' | relative_url }}">
</head>
<body>
<header><a href="{{ '/' | relative_url }}"><strong>Avkroken dokumentation</strong></a> · automatisk lässpegel</header>
<main>{{ content }}</main>
<footer>Canonical källa är alltid respektive repository.</footer>
</body>
</html>""",
        encoding="utf-8",
    )

    (out / "assets" / "style.css").write_text(
        """body{max-width:1100px;margin:0 auto;padding:0 24px 48px;font:16px/1.6 system-ui,sans-serif;color:#24292f}
header{padding:22px 0;border-bottom:1px solid #d0d7de}main{padding:24px 0}footer{margin-top:44px;padding-top:18px;border-top:1px solid #d0d7de;color:#57606a}
a{color:#0969da}pre{overflow:auto;padding:12px;background:#f6f8fa}blockquote{margin-left:0;padding-left:12px;border-left:4px solid #d0d7de;color:#57606a}
table{border-collapse:collapse}th,td{padding:6px 10px;border:1px solid #d0d7de}""",
        encoding="utf-8",
    )

    (out / "_config.yml").write_text(
        'title: "Avkroken dokumentation"\n'
        "markdown: kramdown\n",
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--org", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    out = Path(args.output).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    write_site_shell(out)

    manifest = []
    with tempfile.TemporaryDirectory(prefix="avkroken-docs-") as temp:
        work = Path(temp)

        for repo in discover(args.org):
            name = repo["name"]
            branch = repo["default_branch"]
            src = work / name

            if not clone(repo["clone_url"], src, branch):
                raise RuntimeError(f"Could not clone {repo['full_name']}")

            mirrored_paths = {
                path.relative_to(src).as_posix()
                for path in src.rglob("*")
                if path.is_file() and documentation_file(path, src)
            }

            source_out = out / "repos" / name / "source"
            source_out.mkdir(parents=True, exist_ok=True)
            docs = []

            for rel_str in sorted(mirrored_paths):
                path = src / rel_str
                dst = source_out / rel_str
                dst.parent.mkdir(parents=True, exist_ok=True)

                if path.suffix.lower() == ".md":
                    canonical = (
                        f"https://github.com/{args.org}/{name}"
                        f"/blob/{branch}/{rel_str}"
                    )
                    body = rewrite_repo_links(
                        path.read_text(encoding="utf-8", errors="replace"),
                        org=args.org,
                        repo=name,
                        branch=branch,
                        current_rel=rel_str,
                        mirrored_files=mirrored_paths,
                    )
                    dst.write_text(
                        frontmatter(f"{name} — {rel_str}", canonical, body),
                        encoding="utf-8",
                    )
                    docs.append(rel_str)
                else:
                    shutil.copy2(path, dst)

            wiki_docs = []
            wiki_src = work / f"{name}.wiki"
            wiki_out = out / "repos" / name / "wiki"
            wiki_out.mkdir(parents=True, exist_ok=True)

            if clone(f"https://github.com/{args.org}/{name}.wiki.git", wiki_src):
                wiki_files = {
                    path.relative_to(wiki_src).as_posix()
                    for path in wiki_src.rglob("*.md")
                    if not path.is_symlink() and ".git" not in path.parts
                }
                for rel_str in sorted(wiki_files):
                    path = wiki_src / rel_str
                    if path.name.startswith("_"):
                        continue
                    dst = wiki_out / rel_str
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    canonical = (
                        f"https://github.com/{args.org}/{name}/wiki/"
                        f"{path.stem.replace(' ', '-')}"
                    )
                    body = rewrite_wiki_links(
                        path.read_text(encoding="utf-8", errors="replace"),
                        wiki_files,
                        rel_str,
                    )
                    dst.write_text(
                        frontmatter(f"{name} Wiki — {path.stem}", canonical, body),
                        encoding="utf-8",
                    )
                    wiki_docs.append(rel_str)

            repo_index = out / "repos" / name / "index.md"
            repo_index.parent.mkdir(parents=True, exist_ok=True)

            source_links = "\n".join(
                f"- [{path}](source/{path[:-3]}.html)"
                for path in docs
                if path.lower().endswith(".md")
            ) or "_Ingen versionsstyrd Markdown hittades._"

            wiki_links = "\n".join(
                f"- [{path}](wiki/{path[:-3]}.html)"
                for path in wiki_docs
            ) or "_Inga Wiki-sidor kunde speglas vid denna build._"

            repo_index.write_text(
                "---\nlayout: default\n"
                f'title: "{name}"\n---\n\n'
                f"# {name}\n\n"
                "**Automatisk lässpegel.** Canonical källa är repositoryt.\n\n"
                f"- [Repository]({repo['html_url']})\n"
                f"- [Wiki]({repo['html_url']}/wiki)\n"
                f"- [Issues]({repo['html_url']}/issues)\n"
                f"- [Discussions]({repo['html_url']}/discussions)\n\n"
                "## Versionsstyrd dokumentation\n\n"
                f"{source_links}\n\n"
                "## Wiki\n\n"
                f"{wiki_links}\n",
                encoding="utf-8",
            )

            manifest.append(
                {
                    "repository": repo["full_name"],
                    "default_branch": branch,
                    "canonical": repo["html_url"],
                    "docs": docs,
                    "wiki_pages": wiki_docs,
                }
            )

    index = [
        "---",
        "layout: default",
        'title: "Avkroken dokumentation"',
        "---",
        "",
        "# Avkroken — samlad dokumentation",
        "",
        "> **Automatisk lässpegel.** Varje repository äger sin egen dokumentation, Wiki, Issues och Discussions.",
        "",
    ]
    for item in manifest:
        name = item["repository"].split("/", 1)[1]
        index += [
            f"## [{name}](repos/{name}/)",
            "",
            f"- [Canonical repository]({item['canonical']})",
            f"- [Wiki]({item['canonical']}/wiki)",
            f"- [Issues]({item['canonical']}/issues)",
            f"- [Discussions]({item['canonical']}/discussions)",
            "",
        ]

    (out / "index.md").write_text("\n".join(index), encoding="utf-8")
    (out / "mirror-manifest.json").write_text(
        json.dumps(
            {
                "organization": args.org,
                "canonical": "source repositories",
                "generated_mirror": True,
                "repositories": manifest,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
