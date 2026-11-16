// Configuration publique du site (ces valeurs ne sont pas secrètes : la sécurité est assurée par les règles de la base).
window.ODM_CONFIG = {
  // Supabase → Project Settings → API (ou « Connect »)
  supabase_url: "https://jwseyltlaeweprwlooib.supabase.co",
  supabase_key: "sb_publishable_tLvG7iauPnHR8HihhNpecw_ROd2svon", // clé « publishable » (ou « anon public »), JAMAIS la clé secrète / service_role
  // Identifiant (UUID) de l'utilisateur affiché aux visiteurs non connectés.
  // Supabase → Authentication → Users → copier « User UID ».
  utilisateur_public: "0e378e24-25a8-409e-bcd4-ec1f94abac6f"
};
