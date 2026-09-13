const GITHUB_API =
  "https://api.github.com/orgs/Avkroken/repos?type=public&per_page=100&sort=full_name&direction=asc";

const CACHE_SECONDS = 300;

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

async function getPortalSites(env, ctx) {
  const cache = caches.default;
  const cacheKey = new Request("https://avkroken-cache.invalid/github-sites-v5");
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

    return env.ASSETS.fetch(request);
  }
};
