// Configuration publique du site (ces valeurs ne sont pas secrètes : la sécurité est assurée par les règles de la base).
window.ODM_CONFIG = {
  // Supabase → Project Settings → API (ou « Connect »)
  supabase_url: "",
  supabase_key: "", // clé « publishable » (ou « anon public »), JAMAIS la clé secrète / service_role
  // Identifiant (UUID) de l'utilisateur affiché aux visiteurs non connectés.
  // Supabase → Authentication → Users → copier « User UID ».
  utilisateur_public: ""
};
