// Fonction Supabase « lire-photo » : lit une photo de compteur, de ticket ou de bonbonne
// avec Claude et renvoie les valeurs trouvées. La photo n'est jamais enregistrée.
//
// Secret à définir dans Supabase (Edge Functions → Secrets) : ANTHROPIC_API_KEY
// SUPABASE_URL et SUPABASE_ANON_KEY sont fournis automatiquement par Supabase.
import Anthropic from "npm:@anthropic-ai/sdk@1.2.0";
import { betaZodOutputFormat } from "npm:@anthropic-ai/sdk@1.2.0/helpers/beta/zod";
import { z } from "npm:zod@4.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

// Modèle utilisé pour lire les photos. Claude Haiku 5.5 ("claude-haiku-5-5") coûte ~40× moins cher.
const MODELE = "claude-opus-5-5";

const Lecture = z.object({
  categorie: z.enum(["electricite", "carburant", "gaz", "inconnu"]),
  date: z.string().nullable().describe("Date au format AAAA-MM-JJ si elle est visible, sinon null"),
  index_kwh: z.number().nullable().describe("Index du compteur électrique en kWh"),
  litres: z.number().nullable(),
  euros: z.number().nullable().describe("Montant total payé en euros"),
  prix_litre: z.number().nullable(),
  km: z.number().nullable().describe("Compteur kilométrique total du véhicule"),
  kg: z.number().nullable().describe("Poids de gaz de la bonbonne"),
  lieu: z.string().nullable().describe("Ville ou station"),
  remarque: z.string().describe("Une phrase courte en français : doutes de lecture, valeur choisie s'il y en a plusieurs"),
});

const CONSIGNE = `Tu lis des photos prises pour suivre des consommations personnelles.
Identifie ce que montre la photo :
- "electricite" : un compteur électrique. Donne l'index affiché en kWh (chiffres avant la virgule et décimales si elles sont visibles). S'il y a plusieurs registres (heures pleines / creuses), prends le total ou signale-le dans la remarque.
  Les petits compteurs modulaires de tableau électrique ont souvent un afficheur LCD à 7 segments monté à la verticale : le texte est tourné de 90°. Repère d'abord le sens de lecture grâce aux inscriptions imprimées (« kWh », référence, tension) et lis les chiffres dans ce sens ; attention aux 6 et 9 qui s'échangent quand on lit à l'envers. Sur ces afficheurs, les deux derniers chiffres sont en général les décimales.
- "carburant" : un ticket de carte bancaire ou de pompe, un affichage de pompe, ou un tableau de bord. Donne litres, montant total en euros, prix au litre, date, station ou ville ; et le kilométrage total si un compteur kilométrique est visible.
- "gaz" : une bonbonne ou un ticket d'achat de gaz. Donne le prix et le poids (kg).
- "inconnu" : rien de tout ça.
Pour la valeur principale (index, litres, montant, kilométrage), donne toujours ta meilleure lecture : la personne vérifie avant d'enregistrer. Explique tes doutes dans la remarque. Les autres champs illisibles ou absents valent null. Un nombre s'écrit avec un point décimal.
Si des relevés précédents sont fournis, utilise-les pour vérifier la vraisemblance : un index de compteur ou un kilométrage ne baisse jamais et augmente en général peu d'un relevé à l'autre. Si ta lecture est incohérente avec eux, relis la photo (sens, ordre et nombre des chiffres) avant de répondre.
La date du jour est donnée dans le message pour t'aider à lire une date abrégée ; ne la recopie pas : le champ date vient uniquement de la photo.`;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ erreur: "POST attendu" }, 405);

  // Réservé aux comptes connectés : personne d'autre ne peut consommer le crédit API.
  const jeton = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);
  const { data: user, error: errUser } = await sb.auth.getUser(jeton);
  if (errUser || !user?.user) return json({ erreur: "connexion requise" }, 401);

  let image: string, contexte: unknown;
  try {
    ({ image, contexte } = await req.json());
  } catch {
    return json({ erreur: "corps JSON invalide" }, 400);
  }
  if (typeof image !== "string" || image.length < 100) return json({ erreur: "image manquante" }, 400);
  if (image.length > 7_000_000) return json({ erreur: "image trop lourde" }, 413);
  image = image.replace(/^data:image\/\w+;base64,/, "");

  const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });
  try {
    const rep = await client.beta.messages.parse({
      model: MODELE,
      max_tokens: 4000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default", // si le modèle décline, l'API relance la demande sur un autre modèle
      output_config: { effort: "medium", format: betaZodOutputFormat(Lecture) },
      system: CONSIGNE,
      messages: [{
        role: "user",
        content: [
          { type: "image", source: { type: "base64", media_type: "image/jpeg", data: image } },
          { type: "text", text: `Date du jour : ${new Date().toISOString().slice(0, 10)}.\n${typeof contexte === "string" && contexte ? "Relevés précédents : " + contexte.slice(0, 500) + "\n" : ""}Lis cette photo.` },
        ],
      }],
    });
    if (rep.stop_reason === "refusal") return json({ erreur: "photo refusée par le modèle" }, 422);
    if (!rep.parsed_output) return json({ erreur: "lecture impossible" }, 422);
    return json({ lecture: rep.parsed_output, usage: rep.usage });
  } catch (e) {
    if (e instanceof Anthropic.AuthenticationError) return json({ erreur: "clé ANTHROPIC_API_KEY invalide ou absente" }, 500);
    if (e instanceof Anthropic.RateLimitError) return json({ erreur: "trop de demandes, réessaie dans une minute" }, 429);
    if (e instanceof Anthropic.APIError) return json({ erreur: `API Claude ${e.status} : ${e.message}` }, 502);
    return json({ erreur: String(e) }, 500);
  }
});
