# SENTRA Health

**National Health Intelligence & Citizen Health Journey Platform — working prototype**

> ⚠️ **This is a prototype on synthetic data.** It is not connected to SATUSEHAT,
> BPJS/JKN, Dukcapil, any hospital, laboratory or pharmacy, or any live health
> system. Every record shown is generated. No real person's data is involved.

An intelligence and orchestration layer over the health systems that already
exist. It does not replace an electronic medical record, a payer system or a
national health platform — it links a person's records into one journey, turns
that journey into explainable risk signals, and routes those signals to a human
who can act on them.

---

## Quick start

Requires PHP 8.2+, Composer, Node 20+.

```bash
composer install
npm install

cp .env.example .env
php artisan key:generate

php artisan migrate:fresh --seed    # ~25s — builds the full synthetic dataset
npm run build

php artisan serve
```

Open **http://127.0.0.1:8000**.

### Windows shortcut

`start-sentra.bat` in the project root starts the server on port **8010** and opens
the browser. Desktop shortcuts point at it:

- **SENTRA Health Prototype** — starts the app
- **SENTRA Health (source)** — opens this folder

Port 8010 rather than 8000, because another local project already serves on 8000.

For frontend development with hot reload, run `npm run dev` alongside
`php artisan serve`.

### Demo accounts

Password for all of them is `password`. **Development only.**

| Account | Role | What to look at |
|---|---|---|
| `citizen@example.com` | Citizen | Budi Santoso, 52 — metabolic risk emerging over a decade |
| `citizen2@example.com` | Citizen | Siti Nurhaliza, 34 — the counter-example: low across the board |
| `doctor@example.com` | Doctor | dr. Sari Wulandari — two consented patients |
| `government@example.com` | Ministry of Health | Aggregate population intelligence |
| `sentra@example.com` | SENTRA operator | Cross-domain signals, alerts, audit |
| `admin@example.com` | System admin | Development-only role |

**Follow `DEMO.md` for the guided walkthrough** — about 10 minutes, covering the
full path from a citizen's timeline to a cross-ministry alert and its measured
outcome.

---

## Stack

| | |
|---|---|
| Backend | Laravel 12, PHP 8.2, Sanctum bearer tokens |
| API | Versioned REST at `/api/v1` |
| Frontend | React 19, TypeScript, Vite, React Router, TanStack Query |
| Styling | Tailwind v4 with CSS-variable design tokens, hand-written shadcn-style primitives |
| Charts | Recharts |
| Database | SQLite for local development; migrations written PostgreSQL-compatible |
| Tests | PHPUnit — 34 tests, 220 assertions |

### On the database

The target is PostgreSQL. Local development uses SQLite because it needs no
setup. The migrations avoid database `ENUM`s, `after()` positioning and raw SQL,
so switching is a `.env` change plus a re-migrate. **This has not yet been
verified against a live PostgreSQL instance** — see `DATABASE.md`.

---

## What actually works

Not a mockup. Every item below is backed by a real database, a real API and
enforced permissions:

- **Citizen portal** — dashboard, 20+ year timeline with provenance on every
  event, diagnoses, laboratory results with trends and reference ranges,
  medication with adherence, vaccinations, visits, synthetic payer data,
  emergency card, profile.
- **Risk engine** — eight independent dimensions, deterministic, each with
  evidence, confidence, missing-information and stated limitations. **No
  universal health score**, enforced by a schema test.
- **Explainable AI** — the "Why?" path, grounded question answering that
  **refuses** rather than inventing, and a clinical summary that proposes no
  diagnosis or treatment.
- **Clinical portal** — consent-gated patient access, work queue ordered by
  signal strength, AI clinical summary, withheld categories shown explicitly.
- **Government portal** — population, disease, regions, facilities, medicine,
  workforce, risk distribution, projections. Aggregate only, with small-cell
  suppression.
- **SENTRA Core** — data sources, health graph, cross-domain intelligence, the
  worked dengue alert combining four domains, interventions with named owners and
  measured outcomes, full audit trail including denials.
- **Governance** — consent centre, citizen-visible access log, correction
  workflow, two separate audit trails.

---

## The three things worth understanding

**1. No universal health score.** Combining independent clinical signals into one
number is scientifically weak and invites bad decisions. Risk is eight separate
dimensions. `RiskEngineTest` inspects the live schema and fails if a composite
score column ever appears.

**2. Consent is enforced, not promised.** A clinical role permission is never
sufficient. Reading a patient record also requires an active consent covering
that specific data category, checked at read time, and the read writes a row the
patient can see. Revoking access takes effect on the next request — tested.

**3. Government cannot reach an individual.** Structurally, not by convention:
aggregate tables carry no patient foreign key, no role holds both
`population.read` and any `patient.read.*` (asserted by a test over the role
matrix), and counts below the aggregation threshold are suppressed rather than
rounded.

---

## Commands

```bash
php artisan migrate:fresh --seed   # rebuild the synthetic dataset (deterministic)
php vendor/bin/phpunit             # run the test suite
php vendor/bin/phpunit --testdox   # readable test output
npm run build                      # production assets
npm run dev                        # dev server with hot reload
npm run type-check                 # tsc --noEmit
php artisan route:list --path=api  # the API surface
```

---

## Documentation

| File | What it covers |
|---|---|
| `ARCHITECTURE.md` | Layers, request path, directory structure, the integration seam, why a modular monolith |
| `DATABASE.md` | 35 tables, the provenance contract, the timeline spine, Postgres portability |
| `API.md` | Every endpoint, conventions, an annotated risk object |
| `SECURITY.md` | What is implemented and tested — and what is explicitly **not done** |
| `AI.md` | The risk engine, the language layer, the safety envelope, the refusal path |
| `INTEGRATION.md` | What each real adapter would require, and why none was invented |
| `PRODUCT.md` | Vision, principles, language, who this is for |
| `ROADMAP.md` | What is next, ordered by what unblocks what |
| `DEMO.md` | The guided walkthrough |

---

## Honest limitations

- **The risk model is not clinically validated.** The dimensions are plausible
  and internally consistent; they have not been reviewed against any guideline or
  population. Treat it as an architecture demonstration.
- **No real integrations.** By design — see `INTEGRATION.md` for why inventing an
  API contract is worse than admitting you do not have one.
- **Not production-ready.** No encryption at rest, no TLS, no key management, no
  penetration testing, no backups. See the "Not done" table in `SECURITY.md`.
- **English only.** Localisation is an open item.
- **Postgres unverified.** Written to be compatible, never run there.
- **Not load-tested.** Nobody has measured concurrent behaviour.
