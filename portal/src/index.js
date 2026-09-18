const GITHUB_API =
  "https://api.github.com/orgs/Avkroken/repos?type=public&per_page=100&sort=full_name&direction=asc";

const CACHE_SECONDS = 300;
const DOCS_CACHE_SECONDS = 3600;
const DOC_CONTENT_CACHE_SECONDS = 900;
const MAX_DOC_DEPTH = 2;

const CATEGORY_TOPICS = {
  tool: "Verktyg",
  project: "Projekt",
  docs: "Dokumentation",
  service: "Tjänst",
  experiment: "Experiment"
};

const ACCENT_TOPICS = ["cyan", "blue", "violet", "magenta", "pink"];

function normalizedTopicName(topic) {
  if (typeof topic !== "string") return "";
  return topic.startsWith("portal-") ? topic.slice("portal-".length) : topic;
}

function hasPortalCategory(topics = []) {
  return topics.some(topic => Boolean(CATEGORY_TOPICS[normalizedTopicName(topic)]));
}

function categoryFromTopics(topics = []) {
  for (const topic of topics) {
    const name = normalizedTopicName(topic);
    if (CATEGORY_TOPICS[name]) return CATEGORY_TOPICS[name];
  }
  return "Projekt";
}

function accentFromTopics(topics = []) {
  for (const topic of topics) {
    const name = normalizedTopicName(topic);
    if (ACCENT_TOPICS.includes(name)) return name;
  }
  return "blue";
}

function isPublicHttpsUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "https:";
  } catch {
    return false;
  }
}

function githubHeaders(env, accept = "application/vnd.github+json") {
  const headers = {
    "Accept": accept,
    "X-GitHub-Api-Version": "2026-03-10",
    "User-Agent": "Avkroken-Portal-Worker"
  };
  if (env.GITHUB_TOKEN) headers.Authorization = "Bearer " + env.GITHUB_TOKEN;
  return headers;
}

function encodedPath(path) {
  return String(path || "").split("/").map(segment => encodeURIComponent(segment)).join("/");
}

function pageLabel(path) {
  const name = path.split("/").pop() || path;
  const stem = name.replace(/\.(md|markdown)$/i, "");
  const known = {
    "README": "Översikt",
    "index": "Översikt",
    "architecture": "Arkitektur",
    "operations": "Drift",
    "security": "Säkerhet",
    "project-context": "Projektkontext",
    "engineering-context": "Engineering context",
    "deployment": "Deployment",
    "authentication": "Autentisering",
    "automation": "Automation",
    "discovery": "Discovery",
    "providers": "Providers"
  };
  if (known[stem]) return known[stem];
  return stem.replace(/[-_]+/g, " ").replace(/\b\w/g, char => char.toUpperCase());
}

async function fetchGitHubJson(url, env) {
  const response = await fetch(url, { headers: githubHeaders(env) });
  if (!response.ok) return { ok: false, status: response.status, data: null };
  return { ok: true, status: response.status, data: await response.json() };
}

async function scanMarkdownDocs(repo, env, path = "docs", depth = 0) {
  if (depth > MAX_DOC_DEPTH) return [];
  const endpoint = "https://api.github.com/repos/Avkroken/" + encodeURIComponent(repo.name) +
    "/contents/" + encodedPath(path) + "?ref=" + encodeURIComponent(repo.default_branch);
  const result = await fetchGitHubJson(endpoint, env);
  if (!result.ok || !Array.isArray(result.data)) return [];

  const files = result.data
    .filter(item => item && item.type === "file" && /\.(md|markdown)$/i.test(item.name || ""))
    .map(item => ({ path: item.path, label: pageLabel(item.path) }));

  if (depth < MAX_DOC_DEPTH) {
    const directories = result.data.filter(item => item && item.type === "dir");
    const nested = await Promise.all(
      directories.map(item => scanMarkdownDocs(repo, env, item.path, depth + 1))
    );
    nested.forEach(items => files.push(...items));
  }

  return files;
}

async function readmePage(repo, env) {
  const endpoint = "https://api.github.com/repos/Avkroken/" + encodeURIComponent(repo.name) +
    "/readme?ref=" + encodeURIComponent(repo.default_branch);
  const result = await fetchGitHubJson(endpoint, env);
  if (!result.ok || !result.data || typeof result.data.path !== "string") return null;
  return { path: result.data.path, label: "Översikt" };
}

function pageSort(a, b) {
  const rank = value => value.path === "docs/index.md" ? 0 : value.path === "README.md" ? 1 : 2;
  const diff = rank(a) - rank(b);
  if (diff !== 0) return diff;
  return a.path.localeCompare(b.path, "sv");
}

async function buildDocsEntry(repo, env) {
  const [docs, readme] = await Promise.all([
    scanMarkdownDocs(repo, env),
    readmePage(repo, env)
  ]);

  const pages = [...docs];
  if (readme && !pages.some(page => page.path === readme.path)) pages.push(readme);
  pages.sort(pageSort);

  return {
    name: repo.name,
    description: repo.description || "",
    repository: repo.html_url,
    issues: repo.html_url + "/issues",
    language: repo.language || null,
    updatedAt: repo.pushed_at || repo.updated_at || null,
    defaultBranch: repo.default_branch,
    hasPages: repo.has_pages === true,
    pagesUrl: repo.has_pages === true
      ? "https://avkroken.github.io/" + encodeURIComponent(repo.name) + "/"
      : null,
    pages
  };
}

async function loadDocsCatalog(env, ctx) {
  const cache = caches.default;
  const cacheKey = new Request("https://avkroken-cache.invalid/docs-catalog-v1");
  const cached = await cache.match(cacheKey);
  if (cached) return cached.json();

  const github = await fetch(GITHUB_API, { headers: githubHeaders(env) });
  if (!github.ok) throw new Error("github_unavailable:" + github.status);

  const repos = (await github.json()).filter(repo =>
    repo && repo.visibility === "public" && repo.archived === false
  );
  const entries = await Promise.all(repos.map(repo => buildDocsEntry(repo, env)));
  entries.sort((a, b) => a.name.localeCompare(b.name, "sv"));

  const response = new Response(JSON.stringify(entries), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "public, max-age=" + DOCS_CACHE_SECONDS
    }
  });
  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return entries;
}

async function getDocsCatalog(env, ctx) {
  try {
    const entries = await loadDocsCatalog(env, ctx);
    return new Response(JSON.stringify(entries), {
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=" + DOCS_CACHE_SECONDS
      }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "github_unavailable" }), {
      status: 502,
      headers: { "Content-Type": "application/json; charset=utf-8" }
    });
  }
}

async function getDocContent(requestUrl, env, ctx) {
  const repoName = requestUrl.searchParams.get("repo") || "";
  const path = requestUrl.searchParams.get("path") || "";

  let catalog;
  try {
    catalog = await loadDocsCatalog(env, ctx);
  } catch {
    return new Response(JSON.stringify({ error: "github_unavailable" }), {
      status: 502,
      headers: { "Content-Type": "application/json; charset=utf-8" }
    });
  }

  const repo = catalog.find(entry => entry.name === repoName);
  const page = repo?.pages.find(entry => entry.path === path);
  if (!repo || !page) {
    return new Response(JSON.stringify({ error: "document_not_found" }), {
      status: 404,
      headers: { "Content-Type": "application/json; charset=utf-8" }
    });
  }

  const cache = caches.default;
  const cacheKey = new Request(
    "https://avkroken-cache.invalid/docs-content-v1/" + encodeURIComponent(repoName) +
    "/" + encodeURIComponent(path)
  );
  const cached = await cache.match(cacheKey);
  if (cached) return cached;

  const endpoint = "https://api.github.com/repos/Avkroken/" + encodeURIComponent(repoName) +
    "/contents/" + encodedPath(path) + "?ref=" + encodeURIComponent(repo.defaultBranch);
  const github = await fetch(endpoint, {
    headers: githubHeaders(env, "application/vnd.github.raw+json")
  });
  if (!github.ok) {
    return new Response(JSON.stringify({ error: "document_unavailable", status: github.status }), {
      status: github.status === 404 ? 404 : 502,
      headers: { "Content-Type": "application/json; charset=utf-8" }
    });
  }

  const markdown = await github.text();
  if (markdown.length > 250000) {
    return new Response(JSON.stringify({ error: "document_too_large" }), {
      status: 413,
      headers: { "Content-Type": "application/json; charset=utf-8" }
    });
  }

  const response = new Response(JSON.stringify({
    repo: repo.name,
    path,
    label: page.label,
    markdown,
    sourceUrl: repo.repository + "/blob/" + encodeURIComponent(repo.defaultBranch) + "/" + path.split("/").map(encodeURIComponent).join("/")
  }), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "public, max-age=" + DOC_CONTENT_CACHE_SECONDS
    }
  });
  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}

async function getPortalSites(env, ctx) {
  const cache = caches.default;
  const cacheKey = new Request("https://avkroken-cache.invalid/github-sites-v6");
  const cached = await cache.match(cacheKey);
  if (cached) return cached;

  const headers = {
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2026-03-10",
    "User-Agent": "Avkroken-Portal-Worker"
  };

  if (env.GITHUB_TOKEN) headers.Authorization = `Bearer ${env.GITHUB_TOKEN}`;

  const github = await fetch(GITHUB_API, { headers });
  if (!github.ok) {
    return new Response(
      JSON.stringify({ error: "github_unavailable", status: github.status }),
      { status: 502, headers: { "Content-Type": "application/json; charset=utf-8" } }
    );
  }

  const repos = await github.json();
  const sites = repos
    .filter(repo =>
      repo &&
      repo.visibility === "public" &&
      repo.archived === false &&
      Array.isArray(repo.topics) &&
      hasPortalCategory(repo.topics) &&
      typeof repo.homepage === "string" &&
      isPublicHttpsUrl(repo.homepage)
    )
    .map(repo => {
      const url = new URL(repo.homepage);
      return {
        name: repo.name,
        url: url.href,
        host: url.host,
        description: repo.description || "",
        category: categoryFromTopics(repo.topics),
        accent: accentFromTopics(repo.topics),
        repository: repo.html_url,
        issues: `${repo.html_url}/issues`,
        documentation: "/#docs/" + encodeURIComponent(repo.name),
        pages: repo.has_pages === true
          ? "https://avkroken.github.io/" + encodeURIComponent(repo.name) + "/"
          : null,
        language: repo.language || null,
        repoSizeKb: Number.isFinite(repo.size) ? repo.size : null,
        updatedAt: repo.pushed_at || repo.updated_at || null,
        stars: Number.isFinite(repo.stargazers_count) ? repo.stargazers_count : 0
      };
    });

  const response = new Response(JSON.stringify(sites), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": `public, max-age=${CACHE_SECONDS}`
    }
  });

  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === "/api/sites") {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response("Method Not Allowed", { status: 405 });
      }
      return getPortalSites(env, ctx);
    }

    if (url.pathname === "/api/docs") {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response("Method Not Allowed", { status: 405 });
      }
      return getDocsCatalog(env, ctx);
    }

    if (url.pathname === "/api/docs/content") {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response("Method Not Allowed", { status: 405 });
      }
      return getDocContent(url, env, ctx);
    }

    return env.ASSETS.fetch(request);
  }
};
