# Brigit Trivia League — Training Game

A gym-and-running-themed trivia league for Brigit staff: races, laps, sprint bonuses and personal bests. Every round earns points, and points add up across all games played. The more you play (and the better you play), the higher you climb. **Winner = highest total score.**

Runs in any browser: plain HTML + JavaScript, ready for GitHub Pages.

## Events (categories)
🔥 Fire Standards · 📋 Company Policies · 📦 Datasheets · 🧪 Safety Data Sheets · 🎓 Operational Manuals · ✅ Product Certification *(coming soon)* · 🎲 Mixed Bag

## Sectors
Each player picks a sector, and sectors compete on their own table:
Technical Johannesburg · Exports · Passive Fire Containment · Special Risk · Sprinklers & Valves · Fire Detection · Gas Suppression · Portable Extinguishers

## Scoring
- **100 points** per correct answer
- **Speed bonus** up to +100 (more time left = more points)
- **Combo:** 3 correct in a row = ×1.5, 5 in a row = ×2
- Wrong answer or time-out = 0 points and the streak resets
- Every round's points add to the player's season total **and** their sector's total

## League tables
- **Competitors:** rank, sector, games played, accuracy, best round, total points
- **Sectors:** total points, players, games, accuracy
- Filters: This week / This month / All time

## Training element
After every answer the explanation and reference (SANS standard, SDS section, manual) are shown. At full time, players get a review of every question they missed.

## Branding
- **Logo:** add Brigit's logo as `logo.png` next to `index.html`. It appears automatically top-left; without it, a 🏃 badge shows instead.
- **Colours:** ASH palette — teal `#1FD6C4` (main), dark navy backgrounds `#060F16` / `#0A141C` / `#0C1B26`, Brigit orange-red `#F85008` (icons), turquoise `#40E0D0` (correct), alert red `#C8102E` and warning orange `#FF8A4C` (missed), blue `#1E6FAE` (focus). All set at the top of the `<style>` block in `index.html` and `review.html`.

## Files
| File | Purpose |
|---|---|
| `index.html` | Layout and styling |
| `game.js` | Game logic, scoring, league tables |
| `questions.js` | Settings, sectors, categories and offline sample questions |
| `config.js` | Supabase connection (empty = offline mode) |
| `review.html` | Question approval page for approvers |
| `supabase/schema.sql` | Database tables and access rules |

Question format:
```js
{ q: "Question?", options: ["A", "B", "C", "D"], answer: 0, explain: "…", ref: "SDS Section 8" }
```
`answer` is the index of the correct option (options are shuffled each game). Add `draft: true` to hide a question; `comingSoon: true` on a category greys it out.

## Online mode (Brigit's Supabase)
The game runs **offline** (sample questions, scores per device) until `config.js` is filled in. Online it uses the same Supabase database as ASH:

- **Questions** come from `quiz_questions`. Only questions with status *approved* are played.
- **Results** go to `quiz_results`, and every competitor sees one shared league table.
- **Sign-in** uses a one-time email link and accepts `@brigit.co.za` addresses, plus the admin addresses listed in `config.js` (`adminEmails`), which must also be approvers. First-timers choose a display name and sector, and the sector is fixed after that.
- **Approvers** (listed in `quiz_approvers`) get a *Review questions* button that opens `review.html`. There they can edit, approve or reject draft questions.

Status (13 Oct 2026):
- Done: the `quiz_*` tables, access rules and approvers (Donald, Corne, Feri, brigitai@ for testing, and admin sysproai@elveygroup.com) are live in Brigit's Supabase, and `config.js` is filled in with the project URL and publishable key.
- Done: 114 draft questions written from ASH's library (Fire Standards 23, SDS 22, Company Policies 25, Operational Manuals 23, Datasheets 21). They go live once approved on `review.html`.
- To do: add the GitHub Pages address in Supabase → Authentication → URL Configuration (Site URL and Redirect URLs), or sign-in links won't return to the game.
- To do: set up custom SMTP in Supabase → Authentication → Emails before rollout. The built-in mailer only sends a handful of sign-in emails per hour.

The publishable key in `config.js` is designed to be public. Never put a secret (`sb_secret_…`) or service-role key in this repository.

## Publish on GitHub Pages
1. Create a repository and upload these files.
2. **Settings → Pages → Deploy from a branch → main / (root) → Save.**
3. The game is live at `https://<username>.github.io/<repo>/` within a minute.
