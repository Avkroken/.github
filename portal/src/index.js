const GITHUB_API =
  "https://api.github.com/orgs/Avkroken/repos?type=public&per_page=100&sort=full_name&direction=asc";

const CACHE_SECONDS = 300;
const DOCS_CACHE_SECONDS = 21600;
const DOC_CONTENT_CACHE_SECONDS = 21600;
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

function docsRepoTag(repoName) {
  let safe = String(repoName || "")
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-");

  while (safe.startsWith("-")) safe = safe.slice(1);
  while (safe.endsWith("-")) safe = safe.slice(0, -1);

  return "docs-repo-" + (safe || "unknown");
}

function isPublicMarkdownPath(path) {
  const value = String(path || "");
  return /^docs\/.*\.(md|markdown)$/i.test(value) ||
    /^readme\.(md|markdown)$/i.test(value);
}

function changedDocumentationPath(path) {
  return isPublicMarkdownPath(path);
}

function pushTouchesDocumentation(payload) {
  if (!payload || !Array.isArray(payload.commits)) return true;
  if (Number.isFinite(payload.size) && payload.size > payload.commits.length) return true;

  return payload.commits.some(commit =>
    ["added", "modified", "removed"].some(field =>
      Array.isArray(commit?.[field]) &&
      commit[field].some(changedDocumentationPath)
    )
  );
}

async function resolveWebhookSecret(env) {
  const binding = env.AVKROKEN_DOCS_WEBHOOK_SECRET;
  if (!binding || typeof binding.get !== "function") return null;

  const value = await binding.get();
  return typeof value === "string" && value.length > 0 ? value : null;
}

async function verifyGitHubSignature(rawBody, signatureHeader, secret) {
  if (!secret || typeof signatureHeader !== "string" || !signatureHeader.startsWith("sha256=")) {
    return false;
  }

  const hex = signatureHeader.slice("sha256=".length);
  if (!/^[0-9a-f]{64}$/i.test(hex)) return false;

  const signature = new Uint8Array(hex.match(/.{2}/g).map(byte => Number.parseInt(byte, 16)));
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );

  return crypto.subtle.verify(
    "HMAC",
    key,
    signature,
    new TextEncoder().encode(rawBody)
  );
}

async function purgeDocumentationCache(ctx, tags) {
  const uniqueTags = [...new Set(tags.filter(Boolean))];
  if (!uniqueTags.length) return { success: true, errors: [] };

  const delaysMs = [0, 100, 300];
  let lastErrors = [];

  for (const delayMs of delaysMs) {
    if (delayMs > 0) {
      await new Promise(resolve => setTimeout(resolve, delayMs));
    }

    try {
      const result = await ctx.cache.purge({ tags: uniqueTags });
      if (result.success) return result;
      lastErrors = Array.isArray(result.errors) ? result.errors : [];
    } catch (error) {
      lastErrors = [String(error instanceof Error ? error.message : error)];
    }
  }

  return { success: false, errors: lastErrors };
}

async function handleGitHubWebhook(request, env, ctx) {
  const webhookSecret = await resolveWebhookSecret(env);
  if (!webhookSecret) {
    return new Response("Webhook not configured", { status: 503 });
  }

  const delivery = request.headers.get("X-GitHub-Delivery");
  const event = request.headers.get("X-GitHub-Event");
  const signature = request.headers.get("X-Hub-Signature-256");

  if (!delivery || !event || !signature) {
    return new Response("Missing webhook headers", { status: 400 });
  }

  const rawBody = await request.text();
  const verified = await verifyGitHubSignature(
    rawBody,
    signature,
    webhookSecret
  );

  if (!verified) {
    return new Response("Invalid webhook signature", { status: 401 });
  }

  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (event === "ping") {
    return new Response(JSON.stringify({ ok: true, delivery }), {
      headers: { "Content-Type": "application/json; charset=utf-8" }
    });
  }

  const repository = payload?.repository;
  const owner = repository?.owner?.login || repository?.organization?.login;
  if (!repository || String(owner || "").toLowerCase() !== "avkroken") {
    return new Response("Ignored", { status: 202 });
  }

  const repoTag = docsRepoTag(repository.name);
  let tags = [];

  if (event === "push") {
    const expectedRef = "refs/heads/" + repository.default_branch;
    const isPublic = repository.private === false || repository.visibility === "public";

    if (payload.ref !== expectedRef || !isPublic) {
      return new Response("Ignored", { status: 202 });
    }

    if (!pushTouchesDocumentation(payload)) {
      return new Response("No documentation changes", { status: 202 });
    }

    tags = ["docs-catalog", repoTag];
  } else if (event === "repository") {
    tags = ["docs-catalog", repoTag];
    const previousName = payload?.changes?.repository?.name?.from;
    if (previousName) tags.push(docsRepoTag(previousName));
  } else {
    return new Response("Ignored", { status: 202 });
  }

  const purge = await purgeDocumentationCache(ctx, tags);
  if (!purge.success) {
    console.error("Documentation cache purge failed", {
      delivery,
      event,
      repository: repository.full_name,
      tags,
      errors: purge.errors
    });
    return new Response("Cache purge failed", { status: 503 });
  }

  return new Response(JSON.stringify({
    ok: true,
    delivery,
    event,
    repository: repository.full_name,
    purged: [...new Set(tags)]
  }), {
    headers: { "Content-Type": "application/json; charset=utf-8" }
  });
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
  if (!isPublicMarkdownPath(result.data.path)) return null;
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

async function loadDocsCatalog(env) {
  const github = await fetch(GITHUB_API, { headers: githubHeaders(env) });
  if (!github.ok) throw new Error("github_unavailable:" + github.status);

  const repos = (await github.json()).filter(repo =>
    repo && repo.visibility === "public" && repo.archived === false
  );
  const entries = await Promise.all(repos.map(repo => buildDocsEntry(repo, env)));
  entries.sort((a, b) => a.name.localeCompare(b.name, "sv"));
  return entries;
}

async function getDocsCatalog(env) {
  try {
    const entries = await loadDocsCatalog(env);
    return new Response(JSON.stringify(entries), {
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=0, must-revalidate",
        "Cloudflare-CDN-Cache-Control": "public, max-age=" + DOCS_CACHE_SECONDS,
        "Cache-Tag": "docs-catalog"
      }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "github_unavailable" }), {
      status: 502,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store"
      }
    });
  }
}

async function getDocContent(requestUrl, env) {
  const repoName = requestUrl.searchParams.get("repo") || "";
  const requestedPath = requestUrl.searchParams.get("path") || "";

  let catalog;
  try {
    catalog = await loadDocsCatalog(env);
  } catch {
    return new Response(JSON.stringify({ error: "github_unavailable" }), {
      status: 502,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store"
      }
    });
  }

  const repo = catalog.find(entry => entry.name === repoName);
  const page = repo?.pages.find(entry => entry.path === requestedPath);
  if (!repo || !page) {
    return new Response(JSON.stringify({ error: "document_not_found" }), {
      status: 404,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store"
      }
    });
  }

  const endpoint = "https://api.github.com/repos/Avkroken/" + encodeURIComponent(repo.name) +
    "/contents/" + encodedPath(page.path) + "?ref=" + encodeURIComponent(repo.defaultBranch);
  const github = await fetch(endpoint, {
    headers: githubHeaders(env, "application/vnd.github.raw+json")
  });

  if (!github.ok) {
    return new Response(JSON.stringify({ error: "document_unavailable", status: github.status }), {
      status: github.status === 404 ? 404 : 502,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store"
      }
    });
  }

  const markdown = await github.text();
  if (markdown.length > 250000) {
    return new Response(JSON.stringify({ error: "document_too_large" }), {
      status: 413,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store"
      }
    });
  }

  return new Response(JSON.stringify({
    repo: repo.name,
    path: page.path,
    label: page.label,
    markdown,
    sourceUrl: repo.repository + "/blob/" + encodeURIComponent(repo.defaultBranch) + "/" +
      page.path.split("/").map(encodeURIComponent).join("/")
  }), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "public, max-age=0, must-revalidate",
      "Cloudflare-CDN-Cache-Control": "public, max-age=" + DOC_CONTENT_CACHE_SECONDS,
      "Cache-Tag": "docs-catalog," + docsRepoTag(repo.name)
    }
  });
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
      return getDocsCatalog(env);
    }

    if (url.pathname === "/api/docs/content") {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response("Method Not Allowed", { status: 405 });
      }
      return getDocContent(url, env);
    }

    if (url.pathname === "/webhooks/github") {
      if (request.method !== "POST") {
        return new Response("Method Not Allowed", { status: 405 });
      }
      return handleGitHubWebhook(request, env, ctx);
    }

    return env.ASSETS.fetch(request);
  }
};
