import importlib.util
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("docs_build", HERE / "build.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


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
        org="Avkroken",
        repo="Example",
        branch="main",
        current_rel="docs/index.md",
        mirrored_files=mirrored,
    )
    assert "(architecture.html)" in got
    assert "(../SECURITY.html)" in got
    assert "https://github.com/Avkroken/Example/blob/main/src/app.ts" in got
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
        jobb_docs = root / "apps" / "jobb" / "docs"
        jobb_docs.mkdir(parents=True)
        protected = jobb_docs / "security.md"
        protected.write_text("# protected app docs\n", encoding="utf-8")
        assert mod.documentation_file(protected, root) is False


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
        entry_id="document:Avkroken/Example:docs/index.md",
        kind="document",
        repository="Avkroken/Example",
        ref="main",
        source_path="docs/index.md",
        canonical_url="https://github.com/Avkroken/Example/blob/main/docs/index.md",
        title="Example",
        markdown="# Example\n\nPublic docs.",
    )
    assert entry["repository"] == "Avkroken/Example"
    assert entry["ref"] == "main"
    assert entry["sourcePath"] == "docs/index.md"
    assert entry["canonicalUrl"].startswith("https://github.com/Avkroken/Example/")
    assert entry["text"] == "Example Public docs."
    assert entry["truncated"] is False


def test_write_search_index_is_generated_and_versioned():
    with tempfile.TemporaryDirectory() as td:
        out = Path(td)
        payload = mod.write_search_index(
            out,
            "Avkroken",
            [{"id": "repository:Avkroken/Example", "kind": "repository"}],
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
    test_repo_links()
    test_wiki_links()
    test_liquid_is_preserved_as_text()
    test_symlink_is_not_documentation()
    test_monorepo_app_docs_are_not_mirrored()
    test_jekyll_config_matches_html_links()
    test_searchable_text_and_title()
    test_search_index_entry_preserves_canonical_source()
    test_write_search_index_is_generated_and_versioned()
    print("ok")
