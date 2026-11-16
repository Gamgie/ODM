// Faux serveur : authentification Supabase (/auth/v1/user) et API Anthropic (/v1/messages).
// Enregistre la dernière requête reçue par Anthropic dans derniere-requete.json.
const http = require("http"), fs = require("fs"), path = require("path");
http.createServer((req, res) => { let b = ""; req.on("data", c => b += c); req.on("end", () => {
  const json = (code, o) => { res.writeHead(code, {"content-type": "application/json"}); res.end(JSON.stringify(o)); };
  if (req.url.startsWith("/auth/v1/user"))
    return req.headers.authorization === "Bearer bon" ? json(200, {id: "u1", aud: "authenticated", role: "authenticated"}) : json(401, {msg: "invalid JWT"});
  if (req.url.startsWith("/v1/messages")) {
    fs.writeFileSync(path.join(__dirname, ".derniere-requete.json"), JSON.stringify({headers: req.headers, body: JSON.parse(b)}));
    const out = {categorie: "electricite", date: null, index_kwh: 469.46, litres: null, euros: null, prix_litre: null, km: null, kg: null, lieu: null, remarque: "ok"};
    return json(200, {id: "msg_1", type: "message", role: "assistant", model: "x", content: [{type: "text", text: JSON.stringify(out)}], stop_reason: "end_turn", stop_sequence: null, usage: {input_tokens: 1, output_tokens: 1}});
  }
  res.writeHead(404); res.end();
}); }).listen(8790);
