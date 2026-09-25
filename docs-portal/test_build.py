import importlib.util
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


if __name__ == "__main__":
    test_repo_links()
    test_wiki_links()
    print("ok")
