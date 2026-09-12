const grid = document.querySelector("#site-grid");
const count = document.querySelector("#site-count");

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

async function loadSites() {
  try {
    const response = await fetch("/api/sites", { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const sites = await response.json();

    count.textContent = `${sites.length} PUBLIC ENDPOINT${sites.length === 1 ? "" : "S"}`;

    if (!sites.length) {
      grid.innerHTML = `
        <div class="empty">
          <strong>Inga projekt är publicerade i portalen ännu.</strong>
          Lägg ämnet <code>avkroken-portal</code> på ett publikt Avkroken-repo
          och fyll i repots <code>Website</code>-fält.
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
        <p>${escapeHtml(site.description || "Publikt Avkroken-projekt.")}</p>
        <div class="host">${escapeHtml(site.host)}</div>
      </a>`).join("");
  } catch (error) {
    count.textContent = "GITHUB ERROR";
    grid.innerHTML = `
      <div class="empty">
        <strong>Kunde inte läsa projektlistan från GitHub.</strong>
        Försök igen om en stund.
      </div>`;
    console.error(error);
  }
}

loadSites();
