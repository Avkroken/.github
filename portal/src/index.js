const GITHUB_API =
  "https://api.github.com/orgs/Avkroken/repos?type=public&per_page=100&sort=full_name&direction=asc";

const PORTAL_TOPIC = "avkroken-portal";
const CACHE_SECONDS = 300;

function categoryFromTopics(topics = []) {
  const category = topics.find(t => t.startsWith("portal-") && t !== PORTAL_TOPIC);
  if (!category) return "Projekt";

  return {
    "portal-tool": "Verktyg",
    "portal-project": "Projekt",
    "portal-docs": "Dokumentation",
    "portal-service": "Tjänst",
    "portal-experiment": "Experiment"
  }[category] || "Projekt";
}

function accentFromTopics(topics = []) {
  for (const name of ["cyan", "blue", "violet", "magenta", "pink"]) {
    if (topics.includes(`portal-${name}`)) return name;
  }
  return "blue";
}

function isPublicHttpUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

async function getPortalSites(env, ctx) {
  const cache = caches.default;
  const cacheKey = new Request("https://avkroken-cache.invalid/github-sites-v1");
  const cached = await cache.match(cacheKey);
  if (cached) return cached;

  const headers = {
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2026-03-10",
    "User-Agent": "Avkroken-Portal-Worker"
  };

  // Optional. The portal works without a token because it only requests public repositories.
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
      repo.topics.includes(PORTAL_TOPIC) &&
      typeof repo.homepage === "string" &&
      isPublicHttpUrl(repo.homepage)
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
        repository: repo.html_url
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
