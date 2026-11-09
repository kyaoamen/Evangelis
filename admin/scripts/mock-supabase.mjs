// Tiny stand-in for the Supabase REST/Auth APIs, used only to take UI
// screenshots of the signed-in pages without a real project.
//   node scripts/mock-supabase.mjs 54399
// Then build/run the app with NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54399
import http from "node:http";

const port = Number(process.argv[2] ?? 54399);
const now = Date.now();
const day = 86400000;
const iso = (ms) => new Date(ms).toISOString();

export const user = { id: "u-owner", email: "pasteur@lamoisson.example", aud: "authenticated", role: "authenticated" };
const church = {
  id: "c-moisson", slug: "la-moisson", name: "Église Baptiste La Moisson", city: "Dakar", country: "SN",
  timezone: "Africa/Dakar", default_locale: "fr", join_mode: "approval", status: "active", church_type: "Baptiste",
  review_note: null, submitted_for_review_at: iso(now - 9 * day),
};
const church2 = { ...church, id: "c-ambassade", slug: "ambassade-royaume", name: "Église Ambassade du Royaume de Dieu", city: "Abidjan", country: "CI", status: "pending", join_mode: "open" };
const names = [["Aminata", "Diop"], ["Moussa", "Ndiaye"], ["Fatou", "Sow"], ["Ibrahima", "Fall"], ["Awa", "Ba"], ["Jean", "Mendy"], ["Grâce", "Gomis"]];
const profiles = [
  { id: "u-owner", email: user.email, first_name: "Samuel", last_name: "Faye", phone: "+221 77 000 00 01" },
  ...names.map(([f, l], i) => ({ id: `u-${i}`, email: `${f.toLowerCase()}.${l.toLowerCase()}@mail.example`, first_name: f, last_name: l, phone: `+221 77 123 45 ${10 + i}` })),
];
const tables = {
  churches: [church, church2],
  memberships: [
    { id: "m-owner", church_id: church.id, user_id: "u-owner", role: "owner", status: "active", joined_at: iso(now - 40 * day), created_at: iso(now - 40 * day), churches: church },
    { id: "m-owner2", church_id: church2.id, user_id: "u-owner", role: "admin", status: "active", joined_at: iso(now - 4 * day), created_at: iso(now - 4 * day), churches: church2 },
    ...names.map((_, i) => ({ id: `m-${i}`, church_id: church.id, user_id: `u-${i}`, role: i === 0 ? "pastor" : i === 1 ? "editor" : "member", status: i > 4 ? "pending" : "active", joined_at: i > 4 ? null : iso(now - (30 - i) * day), created_at: iso(now - (30 - i) * day) })),
  ],
  profiles,
  platform_admins: [{ user_id: "u-owner" }],
  church_branding: [{ church_id: church.id, logo_url: null, cover_url: null, primary_color: "#1E4D2B", accent_color: "#D9A441", tagline: { fr: "La moisson est grande", en: "The harvest is plentiful" }, welcome_text: { fr: "Enfants, jeunes, femmes et hommes : il y a une place pour vous." }, about_text: null, featured_video_url: null, address: "Sacré-Cœur 3, Dakar", phone: "+221 33 000 00 00", email: "contact@lamoisson.example", website: null, socials: { youtube: "https://youtube.com/@lamoisson" } }],
  event_categories: [{ id: "k1", church_id: church.id, name: { fr: "Retraite", en: "Retreat" }, sort: 1 }, { id: "k2", church_id: church.id, name: { fr: "Jeunesse", en: "Youth" }, sort: 2 }, { id: "k3", church_id: church.id, name: { fr: "Séminaire", en: "Seminar" }, sort: 3 }],
  events: [
    { id: "e1", church_id: church.id, category_id: "k1", title: { fr: "Retraite spirituelle", en: "Spiritual retreat" }, description: { fr: "Trois jours de prière." }, poster_url: null, starts_at: iso(now + 12 * day), ends_at: iso(now + 14 * day), location: "Centre de retraite, Thiès", capacity: 120, max_seats_per_registration: 2, registration_open: true, visibility: "public", published_at: iso(now - day) },
    { id: "e2", church_id: church.id, category_id: "k2", title: { fr: "Soirée jeunesse" }, description: null, poster_url: null, starts_at: iso(now + 4 * day), ends_at: null, location: "Salle polyvalente", capacity: null, max_seats_per_registration: 1, registration_open: true, visibility: "members", published_at: iso(now - day) },
    { id: "e3", church_id: church.id, category_id: "k3", title: { fr: "Séminaire des leaders" }, description: null, poster_url: null, starts_at: iso(now + 25 * day), ends_at: null, location: "Salle principale", capacity: 40, max_seats_per_registration: 1, registration_open: false, visibility: "public", published_at: null },
  ],
  event_registrations: names.slice(0, 5).map((_, i) => ({ id: `r${i}`, event_id: "e1", church_id: church.id, user_id: `u-${i}`, status: i === 4 ? "waitlist" : "confirmed", seats: i === 2 ? 2 : 1, answers: {}, qr_token: `tok${i}`, checked_in_at: i === 0 ? iso(now - 3600e3) : null, created_at: iso(now - (5 - i) * day) })),
  announcements: [
    { id: "a1", church_id: church.id, title: { fr: "72h de prière non-stop" }, body: { fr: "Inscrivez-vous sur un créneau pour porter l'église dans la prière." }, audience: "all", publish_at: iso(now - 5 * 3600e3), push_sent_at: iso(now - 5 * 3600e3), created_at: iso(now - day) },
    { id: "a2", church_id: church.id, title: { fr: "Réunion des ouvriers" }, body: { fr: "Samedi à 15h pour tous les départements." }, audience: "members", publish_at: iso(now + 2 * day), push_sent_at: null, created_at: iso(now) },
  ],
  invites: [{ id: "i1", church_id: church.id, code: "MOISSON1", role: "member", max_uses: 50, uses: 12, expires_at: iso(now + 20 * day), created_at: iso(now - 3 * day) }],
  feedback: [
    { id: "f1", church_id: church.id, user_id: "u-2", kind: "bug", message: "Je ne reçois pas le code de connexion sur Yahoo.", screen: "/login", app_version: "0.1.0-pilot", platform: "android", status: "new", created_at: iso(now - 2 * 3600e3), churches: { name: church.name } },
    { id: "f2", church_id: church.id, user_id: "u-3", kind: "idea", message: "Pouvoir s'inscrire aux départements (chorale, accueil) depuis l'application.", screen: "/c/la-moisson", app_version: "0.1.0-pilot", platform: "web", status: "planned", created_at: iso(now - day), churches: { name: church.name } },
  ],
  church_documents: ["registration_receipt", "founding_minutes", "church_type", "leader_diploma", "leader_id"].map((t, i) => ({ id: `d${i}`, church_id: church2.id, type: t, storage_path: `${church2.id}/${t}.pdf`, file_name: `${t}.pdf`, status: i === 4 ? "rejected" : "submitted", review_note: i === 4 ? "Pièce illisible" : null, created_at: iso(now - day) })),
  church_review_queue: [{ id: church2.id, name: church2.name, slug: church2.slug, city: church2.city, country: church2.country, church_type: "Évangélique", submitted_for_review_at: iso(now - day), documents: 5, owner_name: "Paul Kouassi", owner_email: "paul@ambassade.example" }],
};

function filterRows(table, params) {
  let rows = tables[table] ?? [];
  for (const [k, v] of params) {
    if (["select", "order", "limit", "offset", "on_conflict", "columns"].includes(k)) continue;
    const m = /^(eq|neq|in|gte|lte|is)\.(.*)$/.exec(v);
    if (!m) continue;
    const [, op, raw] = m;
    rows = rows.filter((r) => {
      const val = r[k];
      if (op === "eq") return String(val) === raw;
      if (op === "neq") return String(val) !== raw;
      if (op === "in") return raw.replace(/^\(|\)$/g, "").split(",").map((s) => s.replace(/"/g, "")).includes(String(val));
      if (op === "gte") return String(val) >= decodeURIComponent(raw);
      if (op === "lte") return String(val) <= decodeURIComponent(raw);
      return true;
    });
  }
  return rows;
}

http
  .createServer((req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${port}`);
    const cors = {
      "Access-Control-Allow-Origin": req.headers.origin ?? "*",
      "Access-Control-Allow-Headers": "*",
      "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS,HEAD",
      "Access-Control-Expose-Headers": "Content-Range",
    };
    if (req.method === "OPTIONS") return res.writeHead(204, cors).end();
    const send = (status, body, extra = {}) => {
      res.writeHead(status, { "Content-Type": "application/json", ...cors, ...extra });
      res.end(body === undefined ? "" : JSON.stringify(body));
    };
    if (url.pathname === "/auth/v1/user") return send(200, user);
    if (url.pathname.startsWith("/auth/v1/")) return send(200, {});
    const rpc = /^\/rest\/v1\/rpc\/(.+)$/.exec(url.pathname);
    if (rpc) {
      if (rpc[1] === "check_in") return send(200, [{ registration_id: "r1", event_id: "e1", status: "confirmed", seats: 2, first_name: "Fatou", last_name: "Sow", already_checked_in: false }]);
      return send(200, null);
    }
    const tbl = /^\/rest\/v1\/(.+)$/.exec(url.pathname);
    if (tbl) {
      const rows = filterRows(tbl[1], url.searchParams);
      const range = { "Content-Range": `0-${Math.max(rows.length - 1, 0)}/${rows.length}` };
      if (req.method === "HEAD") return send(200, undefined, range);
      if (req.method !== "GET") return send(201, rows[0] ?? {});
      if ((req.headers.accept ?? "").includes("vnd.pgrst.object")) return rows[0] ? send(200, rows[0]) : send(406, { message: "no rows" });
      return send(200, rows, range);
    }
    send(404, { message: "not found" });
  })
  .listen(port, "127.0.0.1", () => console.log(`mock supabase on :${port}`));
