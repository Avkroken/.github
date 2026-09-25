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


def test_jekyll_config_matches_html_links():
    with tempfile.TemporaryDirectory() as td:
        out = Path(td)
        mod.write_site_shell(out)
        config = (out / "_config.yml").read_text(encoding="utf-8")
        assert "permalink: pretty" not in config


if __name__ == "__main__":
    test_repo_links()
    test_wiki_links()
    test_liquid_is_preserved_as_text()
    test_symlink_is_not_documentation()
    test_jekyll_config_matches_html_links()
    print("ok")
