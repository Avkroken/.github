const fs = require("node:fs");

for (const required of ["profile/README.md", "SECURITY.md", "CONTRIBUTING.md"]) {
  if (!fs.existsSync(required)) throw new Error(`missing public organization file: ${required}`);
}
for (const forbidden of ["portal", "docs", "assets"]) {
  if (fs.existsSync(forbidden)) throw new Error(`public .github boundary violated: ${forbidden}`);
}
console.log("public .github boundary verified");
