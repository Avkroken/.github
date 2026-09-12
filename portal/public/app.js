const grid = document.querySelector("#site-grid");
const count = document.querySelector("#site-count");
const portalState = document.querySelector("#portal-state");

const escapeHtml = (value = "") =>
  String(value).replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;"
  }[c]));

function accentColor(accent) {
  return {
    cyan: "rgba(36,231,232,.22)",
    blue: "rgba(45,155,255,.22)",
    violet: "rgba(119,87,255,.22)",
    magenta: "rgba(213,29,203,.22)",
    pink: "rgba(255,67,139,.22)"
  }[accent] || "rgba(45,155,255,.18)";
}

function formatSize(kb) {
  if (!Number.isFinite(kb) || kb < 0) return "—";
  if (kb < 1024) return `${Math.max(1, Math.round(kb))} KB`;
  return `${(kb / 1024).toFixed(kb >= 10240 ? 0 : 1)} MB`;
}

function formatDate(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat("sv-SE", {
    day: "numeric",
    month: "short",
    year: "numeric"
  }).format(date);
}

function metric(label, value) {
  return `
    <div class="metric">
      <span>${escapeHtml(label)}</span>
      <strong>${escapeHtml(value)}</strong>
    </div>`;
}

async function loadSites() {
  try {
    const response = await fetch("/api/sites", { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const sites = await response.json();

    count.textContent = `${sites.length} ENDPOINT${sites.length === 1 ? "" : "S"}`;
    if (portalState) portalState.textContent = `${sites.length} LIVE`;

    if (!sites.length) {
      grid.innerHTML = `
        <div class="empty">
          <strong>Inga projekt publicerade ännu.</strong>
        </div>`;
      return;
    }

    grid.innerHTML = sites.map(site => `
      <a class="card"
         href="${escapeHtml(site.url)}"
         target="_blank"
         rel="noopener noreferrer"
         style="--glow:${accentColor(site.accent)}">
        <div class="card-top">
          <span class="badge">${escapeHtml(site.category)}</span>
          <span class="arrow" aria-hidden="true">↗</span>
        </div>
        <h3>${escapeHtml(site.name)}</h3>
        <p>${escapeHtml(site.description || "Avkroken-projekt.")}</p>
        <div class="host">${escapeHtml(site.host)}</div>
        <div class="metrics" aria-label="Projektdata">
          ${metric("STACK", site.language || "—")}
          ${metric("REPO", formatSize(site.repoSizeKb))}
          ${metric("UPDATED", formatDate(site.updatedAt))}
        </div>
      </a>`).join("");
  } catch (error) {
    count.textContent = "UNAVAILABLE";
    if (portalState) portalState.textContent = "INDEX OFFLINE";
    grid.innerHTML = `
      <div class="empty">
        <strong>Projektlistan är tillfälligt otillgänglig.</strong>
      </div>`;
    console.error(error);
  }
}

loadSites();
