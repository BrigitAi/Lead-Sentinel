// =====================================================================
// Brigit Trivia League — question generator (Supabase Edge Function)
//
// POST { library: "fire" | "sds" | "policies" | "ops" | "datasheets" | "all", count: number }
// Only people listed in quiz_generators may call it. It picks unused passages from ASH's
// library, asks an AI model for one multiple-choice question per passage,
// and saves them as DRAFTS for approval on review.html.
//
// Secrets (Edge Functions → Secrets):
//   ANTHROPIC_API_KEY   (default provider)   or   OPENAI_API_KEY + LLM_PROVIDER=openai
//   QUIZ_MODEL          optional, overrides the model name
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
// =====================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const LIBRARIES = ["fire", "sds", "policies", "ops", "datasheets"] as const;
type Library = typeof LIBRARIES[number];
const LIBRARY_NAMES: Record<Library, string> = {
  fire: "Fire Standards", sds: "Safety Data Sheets", policies: "Company Policies",
  ops: "Operational Manuals", datasheets: "Product Datasheets",
};
const MAX_PER_CALL = 50;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

type Passage = { source_table: string; source_id: string; source_title: string; chunk_key: string; passage: string };
type Draft = { passage: number; question: string; correct: string; wrong: string[]; explanation: string };

const SYSTEM = `You write quiz questions for Brigit Fire, a South African fire-protection company, to train its staff.
For each numbered passage, write ONE multiple-choice question that a staff member should know for their job.

Rules:
- The answer must be stated clearly in that passage. Never rely on outside knowledge.
- Test a practical, useful fact: a requirement, limit, number, procedure step, hazard, rating or responsibility.
- Skip a passage (return it in "skipped") if it is boilerplate, a table of contents, too fragmentary, or has nothing worth testing.
- Question: clear, under 30 words, no "all/none of the above", no trick wording.
- correct: the right answer, short. wrong: exactly 3 plausible but clearly wrong answers of similar length and style.
- explanation: one or two sentences, under 35 words, in your own words (do not copy long phrases from the passage).
- Plain English. Use SI units and the passage's own numbers.
Return ONLY JSON: {"questions":[{"passage":1,"question":"...","correct":"...","wrong":["...","...","..."],"explanation":"..."}],"skipped":[2]}`;

async function callModel(passages: Passage[], libraryName: string): Promise<{ questions: Draft[]; skipped: number[] }> {
  const provider = (Deno.env.get("LLM_PROVIDER") || "anthropic").toLowerCase();
  const user = `Library: ${libraryName}\n\n` + passages.map((p, i) =>
    `### Passage ${i + 1}\nSource: ${p.source_title}\n${p.passage}`).join("\n\n");

  let text = "";
  if (provider === "openai") {
    const key = Deno.env.get("OPENAI_API_KEY");
    if (!key) throw new Error("OPENAI_API_KEY secret is not set");
    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: Deno.env.get("QUIZ_MODEL") || "gpt-4.1",
        response_format: { type: "json_object" },
        messages: [{ role: "system", content: SYSTEM }, { role: "user", content: user }],
      }),
    });
    if (!r.ok) throw new Error(`OpenAI error ${r.status}: ${(await r.text()).slice(0, 300)}`);
    text = (await r.json()).choices?.[0]?.message?.content ?? "";
  } else {
    const key = Deno.env.get("ANTHROPIC_API_KEY");
    if (!key) throw new Error("ANTHROPIC_API_KEY secret is not set");
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "Content-Type": "application/json" },
      body: JSON.stringify({
        model: Deno.env.get("QUIZ_MODEL") || "claude-sonnet-5-5",
        max_tokens: 8000,
        system: SYSTEM,
        messages: [{ role: "user", content: user }],
      }),
    });
    if (!r.ok) throw new Error(`Anthropic error ${r.status}: ${(await r.text()).slice(0, 300)}`);
    const body = await r.json();
    text = (body.content || []).filter((c: { type: string }) => c.type === "text").map((c: { text: string }) => c.text).join("");
  }
  const start = text.indexOf("{"), end = text.lastIndexOf("}");
  if (start < 0 || end < 0) throw new Error("The model did not return JSON");
  const parsed = JSON.parse(text.slice(start, end + 1));
  return { questions: parsed.questions || [], skipped: parsed.skipped || [] };
}

const clean = (s: unknown, max: number) => String(s ?? "").replace(/\s+/g, " ").trim().slice(0, max);

function validRow(d: Draft, p: Passage | undefined, library: Library) {
  if (!p) return null;
  const question = clean(d.question, 300);
  const correct = clean(d.correct, 200);
  const wrong = (Array.isArray(d.wrong) ? d.wrong : []).map((w) => clean(w, 200)).filter(Boolean);
  const options = [correct, ...wrong.slice(0, 3)];
  if (!question || !correct || options.length !== 4) return null;
  if (new Set(options.map((o) => o.toLowerCase())).size !== 4) return null;
  return {
    library, question, options, correct_index: 0,
    explanation: clean(d.explanation, 400) || null,
    source_table: p.source_table, source_id: p.source_id, source_title: p.source_title,
    source_chunk: p.chunk_key, status: "draft",
  };
}

async function generateFor(admin: ReturnType<typeof createClient>, library: Library, count: number) {
  const { data, error } = await admin.rpc("quiz_pick_passages", { p_library: library, p_count: count });
  if (error) throw new Error(`Picking passages (${library}): ${error.message}`);
  const passages = (data || []) as Passage[];
  if (!passages.length) return { library, created: 0, skipped: 0, note: "No unused passages left" };

  const out = await callModel(passages, LIBRARY_NAMES[library]);
  const rows = out.questions
    .map((d) => validRow(d, passages[(Number(d.passage) || 0) - 1], library))
    .filter((r): r is NonNullable<typeof r> => !!r);
  // one question per passage
  const seen = new Set<string>();
  const unique = rows.filter((r) => !seen.has(r.source_chunk) && seen.add(r.source_chunk));
  if (unique.length) {
    const { error: insErr } = await admin.from("quiz_questions").insert(unique);
    if (insErr) throw new Error(`Saving questions (${library}): ${insErr.message}`);
  }
  return { library, created: unique.length, skipped: passages.length - unique.length };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const authHeader = req.headers.get("Authorization") || "";
  // Who is calling? Must be a signed-in approver.
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: authHeader } } });
  const { data: userData } = await asUser.auth.getUser();
  if (!userData?.user) return json({ error: "Please sign in first." }, 401);
  const { data: canGenerate } = await asUser.rpc("quiz_can_generate");
  if (!canGenerate) return json({ error: "Only Donald Barnard and Deon van Zyl can generate questions." }, 403);

  let body: { library?: string; count?: number } = {};
  try { body = await req.json(); } catch { /* empty body */ }
  const library = String(body.library || "all");
  const count = Math.max(1, Math.min(Number(body.count) || 10, MAX_PER_CALL));
  const targets: Library[] = library === "all" ? [...LIBRARIES]
    : (LIBRARIES as readonly string[]).includes(library) ? [library as Library] : [];
  if (!targets.length) return json({ error: `Unknown library "${library}"` }, 400);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  // "all": spread the count across libraries (at least 1 each)
  const per = library === "all" ? Math.max(1, Math.ceil(count / targets.length)) : count;

  const results = await Promise.all(targets.map((lib) =>
    generateFor(admin, lib, per).catch((e) => ({ library: lib, created: 0, skipped: 0, error: String(e.message || e) }))));
  const created = results.reduce((n, r) => n + r.created, 0);
  const skipped = results.reduce((n, r) => n + r.skipped, 0);
  const errors = results.filter((r) => "error" in r).map((r) => `${r.library}: ${(r as { error: string }).error}`);

  await admin.from("quiz_generation_runs").insert({
    requested_by: userData.user.email, library, requested: count, created, skipped,
    error: errors.length ? errors.join(" | ").slice(0, 1000) : null,
  });

  return json({ created, skipped, results, errors }, errors.length && !created ? 500 : 200);
});
