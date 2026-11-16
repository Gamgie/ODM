// Faux client Supabase pour les tests du site (remplace supabase-js chargé depuis le CDN).
// Données en mémoire dans window.__db ; appels journalisés dans window.__rpc / window.__inv.
window.__db = {releves: [
  {id:1,user_id:"u1",categorie:"electricite",date:"2026-11-04",valeur:408,created_at:"2026-11-16T12:40:00Z"},
  {id:2,user_id:"u1",categorie:"electricite",date:"2026-11-16",valeur:467.33,created_at:"2026-11-16T11:55:00Z"},
  {id:3,user_id:"u1",categorie:"electricite",date:"2026-11-16",valeur:469.40,created_at:"2026-11-16T12:55:00Z"},
  {id:4,user_id:"u1",categorie:"carburant",date:"2026-10-01",valeur:212300,litres:70,euros:125,plein_complet:true},
  {id:5,user_id:"u1",categorie:"carburant",date:"2026-11-16",valeur:213217,litres:72,euros:130,plein_complet:true,lieu:"Lyon"}],
  claude_usage: Array.from({length:300},(_,i)=>{const t=Date.now()-(300-i)*18e5;return {user_id:"u1",ts:new Date(t).toISOString(),session_5h:(i%10)*9,session_5h_reset:new Date(t+(10-i%10)*18e5).toISOString(),semaine:i/5,semaine_reset:new Date(Date.now()+2*864e5).toISOString()}})};
window.__lectures = [];            // réponses successives de la fonction photo (à remplir par le test)
window.__app = [{appareil:"ordinateur",created_at:"2026-11-16T12:00:00Z",dernier_releve:new Date(Date.now()-12*6e4).toISOString()}];
let sess = null, cbs = [], nid = 100;
function q(table){const st={f:[],from:0,to:1e9};const p={select(){return p},order(){return p},range(a,b){st.from=a;st.to=b;return p},eq(k,v){st.f.push([k,v]);return p},
  then(res){res({data:(__db[table]||[]).filter(r=>st.f.every(([k,v])=>r[k]==v)).slice(st.from,st.to+1),error:null})},
  insert(row){__db[table].push({id:nid++,user_id:sess.user.id,created_at:new Date().toISOString(),...row});return Promise.resolve({error:null})},
  delete(){return {eq(k,v){__db[table]=__db[table].filter(r=>r[k]!=v);return Promise.resolve({error:null})}}}};return p}
window.supabase = {createClient: () => ({
  from: q,
  functions: {invoke: async (n, {body}) => { (window.__inv = window.__inv || []).push(body); return {data: {lecture: __lectures.shift()}, error: null}; }},
  rpc: async (n, a) => { (window.__rpc = window.__rpc || []).push([n, a]);
    if (n === "mes_collecteurs") return {data: __app, error: null};
    if (n === "supprimer_collecteur") { window.__app = __app.filter(x => x.appareil !== a.p_appareil); return {data: null, error: null}; }
    if (n === "nouvelle_cle_collecteur") { __app.push({appareil: a.p_appareil, created_at: new Date().toISOString(), dernier_releve: null}); return {data: "cle-" + a.p_appareil, error: null}; }
    return {data: null, error: null}; },
  auth: {getSession: async () => ({data: {session: sess}}), onAuthStateChange: cb => cbs.push(cb),
    signInWithPassword: async ({email}) => { sess = {user: {id: "u1", email}}; cbs.forEach(c => c("SIGNED_IN", sess)); return {error: null}; },
    signOut: async () => { sess = null; cbs.forEach(c => c("SIGNED_OUT", null)); }}
})};
