// Tests du site dans Chromium (Playwright préinstallé), Supabase simulé par stub-supabase.js.
// Lancer depuis la racine du dépôt : node tests/ui.test.js
const {chromium} = require("playwright");
const assert = require("assert/strict");
const http = require("http"), fs = require("fs"), path = require("path");
const RACINE = path.resolve(__dirname, "..");
const CONFIG = 'window.ODM_CONFIG={supabase_url:"https://test.supabase.co",supabase_key:"sb_publishable_test",utilisateur_public:"u1"}';

const serveur = http.createServer((req, res) => {
  const f = path.join(RACINE, decodeURIComponent(req.url.split("?")[0]).replace(/\/$/, "/index.html"));
  if (!f.startsWith(RACINE) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, {"content-type": {".html": "text/html", ".js": "text/javascript", ".json": "application/json"}[path.extname(f)] || "application/octet-stream"});
  fs.createReadStream(f).pipe(res);
}).listen(0);
const URL0 = `http://localhost:${serveur.address().port}/`;
const tests = [];
const test = (nom, fn) => tests.push([nom, fn]);

async function page(b, opts = {}) {
  const p = await b.newPage({viewport: {width: 390, height: 844}, acceptDownloads: true, ...opts});
  p.erreurs = [];
  p.on("pageerror", e => p.erreurs.push(e.message));
  p.on("dialog", d => d.accept());
  await p.route("**/supabase.min.js", r => r.fulfill({path: path.join(__dirname, "stub-supabase.js"), contentType: "text/javascript"}));
  await p.route("**/config.js*", r => r.fulfill({body: CONFIG, contentType: "text/javascript"}));
  await p.goto(URL0); await p.waitForTimeout(800);
  return p;
}
async function connecter(p) {
  await p.click("#compte-btn"); await p.fill("#l-mail", "test@exemple.fr"); await p.fill("#l-pass", "x");
  await p.click("#f-login .main"); await p.waitForTimeout(300);
}
const texte = async (p, sel) => (await p.textContent(sel)).replace(/\s+/g, " ").trim();

test("page publique : version, électricité par périodes de 24 h", async b => {
  const p = await page(b);
  const v = JSON.parse(fs.readFileSync(path.join(RACINE, "version.json"))).version;
  assert.equal(await p.textContent("#version"), String(v), "VERSION de index.html = version.json");
  assert.match(await texte(p, "#elec-tiles"), /4,7\s*kWh\/jour \(dernière période\)/);
  assert.match(await texte(p, "#elec-table"), /\+2,07 kWh en 1 h/);
  assert.equal(await p.isVisible("#fab"), false, "pas de bouton d'ajout sans connexion");
  assert.deepEqual(p.erreurs, []);
});

test("saisie à la main avec virgule et espaces", async b => {
  const p = await page(b); await connecter(p);
  await p.click("#fab"); await p.fill("#a-index", "470,12"); await p.click("#add-ok"); await p.waitForTimeout(300);
  let l = await p.evaluate(() => __db.releves.at(-1));
  assert.equal(l.categorie, "electricite"); assert.equal(l.valeur, 470.12);
  await p.click("#fab"); await p.selectOption("#a-cat", "carburant");
  await p.fill("#a-euros", "130,5"); await p.fill("#a-litres", "72,4"); await p.fill("#a-km", "213 912");
  await p.click("#add-ok"); await p.waitForTimeout(300);
  l = await p.evaluate(() => __db.releves.at(-1));
  assert.equal(l.valeur, 213912); assert.equal(l.litres, 72.4); assert.equal(l.euros, 130.5);
  assert.deepEqual(p.erreurs, []);
});

test("photo : rotation, cadrage, lecture et contexte envoyé", async b => {
  const p = await page(b); await connecter(p);
  await p.evaluate(() => __lectures.push({categorie: "electricite", date: null, index_kwh: 469.46, litres: null, euros: null, prix_litre: null, km: null, kg: null, lieu: null, remarque: "ok"}));
  await p.click("#fab");
  const png = await p.evaluate(() => { const c = document.createElement("canvas"); c.width = 4000; c.height = 3000; const g = c.getContext("2d");
    g.fillStyle = "#ccc"; g.fillRect(0, 0, 4000, 3000); g.fillStyle = "#111"; g.fillRect(1950, 1400, 100, 200); return c.toDataURL("image/png").split(",")[1]; });
  await p.setInputFiles("#a-photo", {name: "t.png", mimeType: "image/png", buffer: Buffer.from(png, "base64")});
  await p.waitForTimeout(400);
  assert.equal(await p.isDisabled("#crop-ok"), true, "lecture désactivée sans zone");
  await p.click("#crop-rot");
  const box = await (await p.$("#crop")).boundingBox();
  await p.mouse.move(box.x + box.width * .4, box.y + box.height * .4); await p.mouse.down();
  await p.mouse.move(box.x + box.width * .6, box.y + box.height * .6, {steps: 4}); await p.mouse.up();
  await p.click("#crop-ok"); await p.waitForTimeout(600);
  const envoi = await p.evaluate(() => __inv.at(-1));
  assert.match(envoi.image, /^data:image\/jpeg;base64,/);
  assert.ok(envoi.image.length < 360000, "image sous ~350 Ko");
  assert.match(envoi.contexte, /Dernier index électrique connu : 469\.4 kWh/);
  assert.equal(await p.inputValue("#a-index"), "469,46");
  assert.deepEqual(p.erreurs, []);
});

test("Mon compte : appareils et installateur Windows", async b => {
  const p = await page(b); await connecter(p);
  await p.click("#compte-btn"); await p.waitForTimeout(300);
  assert.match(await texte(p, "#appareils"), /ordinateur\s*il y a 12 min/);
  await p.fill("#i-appareil", "laptop");
  const [dl] = await Promise.all([p.waitForEvent("download"), p.click("#installer-btn")]);
  assert.equal(dl.suggestedFilename(), "installer-odm-laptop.cmd");
  const cmd = fs.readFileSync(await dl.path(), "utf8");
  assert.match(cmd, /\r\nset "ODM_CLE=cle-laptop"\r\n/); assert.match(cmd, /collecteur\/installer\.ps1/);
  await p.click('[data-appareil="ordinateur"]'); await p.waitForTimeout(300);
  assert.doesNotMatch(await texte(p, "#appareils"), /ordinateur/);
  assert.deepEqual(p.erreurs, []);
});

test("mise à jour automatique si version.json est plus récent", async b => {
  const p = await b.newPage();
  await p.route("**/supabase.min.js", r => r.fulfill({path: path.join(__dirname, "stub-supabase.js"), contentType: "text/javascript"}));
  await p.route("**/config.js*", r => r.fulfill({body: CONFIG, contentType: "text/javascript"}));
  await p.route("**/version.json*", r => r.fulfill({body: '{"version": 99999}', contentType: "application/json"}));
  let chargements = 0; p.on("load", () => chargements++);
  await p.goto(URL0); await p.waitForTimeout(1500);
  assert.equal(chargements, 2, "un seul rechargement, sans boucle"); assert.match(p.url(), /\?v=99999/);
});

(async () => {
  const b = await chromium.launch(); let ko = 0;
  for (const [nom, fn] of tests) {
    try { await fn(b); console.log("✓", nom); } catch (e) { ko++; console.log("✗", nom, "\n   ", e.message.split("\n").slice(0, 4).join("\n    ")); }
  }
  await b.close(); serveur.close();
  console.log(ko ? `${ko} test(s) en échec` : "Tous les tests du site passent"); process.exit(ko ? 1 : 0);
})();
