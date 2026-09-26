import importlib.util
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("docs_build", HERE / "build.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def test_discover_uses_current_user_owner_endpoint():
    seen = []
    original = mod.get_json

    try:
        def fake_get_json(url):
            seen.append(url)
            return []

        mod.get_json = fake_get_json
        assert mod.discover("blixten85") == []
    finally:
        mod.get_json = original

    assert seen == [
        "https://api.github.com/users/blixten85/repos"
        "?type=owner&per_page=100&page=1"
    ]


def test_repo_links():
    mirrored = {
        "README.md",
        "SECURITY.md",
        "docs/index.md",
        "docs/architecture.md",
        "docs/img/a.png",
    }
    text = (
        "[Architecture](architecture.md) "
        "[Security](../SECURITY.md) "
        "[Code](../src/app.ts) "
        "![Image](img/a.png)"
    )
    got = mod.rewrite_repo_links(
        text,
        org="blixten85",
        repo="Example",
        branch="main",
        current_rel="docs/index.md",
        mirrored_files=mirrored,
    )
    assert "(architecture.html)" in got
    assert "(../SECURITY.html)" in got
    assert "https://github.com/blixten85/Example/blob/main/src/app.ts" in got
    assert "![Image](img/a.png)" in got


def test_wiki_links():
    got = mod.rewrite_wiki_links(
        "[Docs](Documentation) [Home](Home.md)",
        {"Documentation.md", "Home.md"},
        "Home.md",
    )
    assert "(Documentation.html)" in got
    assert "(Home.html)" in got


def test_liquid_is_preserved_as_text():
    body = "Use ${{ secrets.EXAMPLE }} and {% if example %}x{% endif %}."
    got = mod.frontmatter("Example", "https://example.invalid", body)
    assert "{% raw %}" in got
    assert "${{ secrets.EXAMPLE }}" in got
    assert "{% if example %}" in got


def test_symlink_is_not_documentation():
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        target = root / "target.md"
        target.write_text("# secret\n", encoding="utf-8")
        docs = root / "docs"
        docs.mkdir()
        link = docs / "linked.md"
        link.symlink_to(target)
        assert link.is_symlink()
        assert mod.documentation_file(link, root) is False


def test_monorepo_app_docs_are_not_mirrored():
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        jobb = root / "apps" / "jobb"
        jobb_docs = jobb / "docs"
        jobb_docs.mkdir(parents=True)

        app_readme = jobb / "README.md"
        app_readme.write_text("# protected app README\n", encoding="utf-8")
        protected = jobb_docs / "security.md"
        protected.write_text("# protected app docs\n", encoding="utf-8")

        assert mod.documentation_file(app_readme, root) is False
        assert mod.documentation_file(protected, root) is False


def test_only_root_readme_and_root_docs_are_mirrored():
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        root_readme = root / "README.md"
        root_readme.write_text("# root\n", encoding="utf-8")
        docs = root / "docs"
        docs.mkdir()
        docs_readme = docs / "README.md"
        docs_readme.write_text("# docs\n", encoding="utf-8")
        nested = root / "tools" / "README.md"
        nested.parent.mkdir()
        nested.write_text("# nested\n", encoding="utf-8")

        assert mod.documentation_file(root_readme, root) is True
        assert mod.documentation_file(docs_readme, root) is True
        assert mod.documentation_file(nested, root) is False


def test_monorepo_is_excluded_from_generic_search_index():
    assert mod.search_repository_allowed("blixten85/Avkroken") is False
    assert mod.search_repository_allowed("blixten85/Bastion") is True


def test_jekyll_config_matches_html_links():
    with tempfile.TemporaryDirectory() as td:
        out = Path(td)
        mod.write_site_shell(out)
        config = (out / "_config.yml").read_text(encoding="utf-8")
        assert "permalink: pretty" not in config


def test_searchable_text_and_title():
    markdown = """---
title: ignored
---

# Search title

Read **public** [documentation](https://example.invalid) safely.
"""
    text, truncated = mod.searchable_text(markdown)
    assert truncated is False
    assert "Search title" in text
    assert "public documentation safely." in text
    assert "https://example.invalid" not in text
    assert mod.document_title(markdown, "Fallback") == "Search title"


def test_search_index_entry_preserves_canonical_source():
    entry = mod.search_entry(
        entry_id="document:blixten85/Example:docs/index.md",
        kind="document",
        repository="blixten85/Example",
        ref="main",
        source_path="docs/index.md",
        canonical_url="https://github.com/blixten85/Example/blob/main/docs/index.md",
        title="Example",
        markdown="# Example\n\nPublic docs.",
    )
    assert entry["repository"] == "blixten85/Example"
    assert entry["ref"] == "main"
    assert entry["sourcePath"] == "docs/index.md"
    assert entry["canonicalUrl"].startswith("https://github.com/blixten85/Example/")
    assert entry["text"] == "Example Public docs."
    assert entry["truncated"] is False


def test_write_search_index_is_generated_and_versioned():
    with tempfile.TemporaryDirectory() as td:
        out = Path(td)
        payload = mod.write_search_index(
            out,
            "blixten85",
            [{"id": "repository:blixten85/Example", "kind": "repository"}],
        )
        stored = __import__("json").loads(
            (out / "search-index.json").read_text(encoding="utf-8")
        )
        assert payload["schemaVersion"] == 1
        assert payload["generatedMirror"] is True
        assert payload["canonical"] == "source repositories"
        assert payload["generatedAt"].endswith("Z")
        assert stored == payload


if __name__ == "__main__":
    test_discover_uses_current_user_owner_endpoint()
    test_repo_links()
    test_wiki_links()
    test_liquid_is_preserved_as_text()
    test_symlink_is_not_documentation()
    test_monorepo_app_docs_are_not_mirrored()
    test_only_root_readme_and_root_docs_are_mirrored()
    test_monorepo_is_excluded_from_generic_search_index()
    test_jekyll_config_matches_html_links()
    test_searchable_text_and_title()
    test_search_index_entry_preserves_canonical_source()
    test_write_search_index_is_generated_and_versioned()
    print("ok")
