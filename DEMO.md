# Demo script

Runs entirely locally. Roughly 10 minutes at a walking pace.

```bash
php artisan migrate:fresh --seed
npm run build
php artisan serve
```

Open http://127.0.0.1:8000. Every account's password is `password`.

> Say this once, at the start: **everything shown is synthetic.** No real
> person's data, and no connection to SATUSEHAT, BPJS, Dukcapil or any hospital.

---

## Act 1 — The citizen (4 min)

**Sign in** as `citizen@example.com` → Budi Santoso, 52, Jakarta Pusat.

**1. My health.** Seven areas, each assessed on its own, each with its own
confidence. Metabolic reads **Elevated — Monitor**.

> Point out what is deliberately *absent*: there is no single overall health
> score. Combining independent clinical signals into one number is scientifically
> weak and invites bad decisions. The line "There is deliberately no single
> overall score" is on the screen.

The banner at the top is the **next recommended action** — drawn from the
highest-priority dimension, not invented.

**2. Health journey.** 24 events across 52 years, grouped by year, filterable.

> Open any entry — a laboratory panel, say. It expands to show **provenance**:
> source system, source record id (`LAB-000923`), when it was recorded, verified
> status, confidence. Nothing in this system is displayed without being traceable
> to where it came from.

Scroll back to the 1970s: the childhood immunisations are there, held at *medium*
confidence because they predate digitisation. They are still *verified* — a paper
record transcribed into a registry really was verified by that registry. That
distinction is why a 52-year-old does not look unvaccinated.

**3. Laboratory.** Trends with the reference range drawn behind the line. A value
means nothing without the band it should sit in.

> Follow HbA1c: 5.2 in 2015 → 7.1 today. The story is in the slope.

**4. Risk signals → the "Why?" button.** This is the centre of the demo.

The metabolic card shows level, a score that is *comparable only within
metabolic*, and 92% confidence. Below it: what is contributing, what is working
in their favour, and — when relevant — what is missing.

Click **Why?**

> The explanation ranks the contributions, each with the actual measurement
> behind it: "HbA1c in diabetic range — Most recent HbA1c 7.1%." Every claim
> traces to a stored record. And it carries its own limits: not a validated risk
> equation, not a diagnosis.

Mention the scoring: HbA1c, fasting glucose and the diabetes diagnosis are
largely one finding stated three times, so factors combine with **diminishing
returns** rather than summing. Otherwise everyone with diabetes scores 100 and
the scale tells you nothing.

**5. Assistant.** Ask *"What changed in my health over the last 5 years?"* — it
answers from the record, with a table of measured deltas and its sources.

Now ask something the record cannot support — *"What was my grandfather's cause
of death?"*

> It refuses: "I don't have enough verified information in your record to answer
> that." Confidence 0. That refusal is the single most important behaviour in the
> AI layer, and it is covered by a test.

**6. Who has access.** Every party that can see part of the record, which
categories, why, and until when — with a withdraw button. Then **Access log**:
every time the record was actually opened, by whom, for what purpose, under which
consent. Written by the system, not by the person doing the accessing.

---

## Act 2 — The clinician (2 min)

Sign out. Sign in as `doctor@example.com` (dr. Sari Wulandari).

**7. Dashboard.** Two consented patients — a work queue ordered by signal
strength, not an alphabetical roster.

> The list contains only patients who granted *this clinician* access. There is
> no global patient index to browse.

**8. Open Budi Santoso.** Note the header: **"Withheld by the patient: Payer"**.
He consented to clinical categories but not to his insurance data, and the
clinician is told what is withheld rather than shown a silently partial record.

**9. AI summary.** Context, recent changes with real deltas, relevant history,
encounters, risk signals, recent results, and *possible follow-up questions*.

> It ends with: "This summary reorganises existing records. It proposes no
> diagnosis and no treatment. Clinical decisions remain with the treating
> clinician."

**10. My access log.** Everything this clinician opened — the same rows the
patient sees on their side. Same events, two audiences.

> Worth demonstrating if there is time: paste a patient id this doctor has no
> consent for. It refuses, and the refusal is written to the audit trail.

---

## Act 3 — Government (2 min)

Sign in as `government@example.com`.

**11. Indonesia health overview.** Population metrics, disease movement, capacity,
risk distribution, and a generated population insight.

> The banner states it: *aggregate only — these screens read tables that carry no
> patient key.* There is no query path from here to an individual. That is
> structural: no role holds both `population.read` and any `patient.read.*`, and
> a test asserts it.

Point at the risk distribution note: cells below the aggregation threshold are
**suppressed**, shown as `·`, not rounded. A count of one in a region is a
person.

**12. Regions → DKI Jakarta.** Regional metrics, six months of environmental
signals, capacity, workforce against target.

> Rainfall rising. Drainage adequacy falling. Remember those two.

---

## Act 4 — SENTRA Core (2 min)

Sign in as `sentra@example.com`.

**13. Alerts → "Elevated dengue risk signal — DKI Jakarta".**

Four signals from four different custodians:

| Domain | Signal | |
|---|---|---|
| Health | Dengue presentations | 186 per 100k, rising |
| Environment | Rainfall | above its six-month average |
| Infrastructure | Drainage adequacy | falling |
| Social | Population density | high |

> No single one of these justifies action. Together they describe conditions in
> which transmission accelerates. That is the whole argument for a cross-domain
> layer — and the alert says plainly that the relationship is correlational, with
> no causal claim, on synthetic data.

**14. Scroll to "Interventions raised from this alert."** Two, each with a named
owner and a status: vector surveillance *in progress*, fluid therapy supplies
*completed*.

> This is where an intelligence platform differs from a dashboard. Open
> **Interventions** and look at the measured outcome: larval survey coverage 41%
> → 68%, with a note that case impact is not yet measurable. Data → signal →
> decision → a named human → a measured outcome.

**15. Health graph.** Entity and relationship counts — the shape of the graph,
never its contents. Note why it is relational rather than a graph database: at
this scale a graph store adds an operational dependency and buys nothing that
indexed foreign keys do not already provide.

**16. Data sources.** Eight sources, each labelled `mock` or `planned`. Nothing is
`connected`, and each carries an integration note stating what a real adapter
would require.

**17. Audit trail.** Every sensitive action — including denials.

> An audit trail that records only successful access cannot show an attack, and
> cannot distinguish a consent gate that is working from one that was never
> reached. Both outcomes are here.

---

## If asked "is this real?"

Be direct: it is a working prototype on synthetic data. The database, API,
authentication, permissions, consent enforcement, audit trail, risk engine and
all four portals are real and tested — 34 tests, including the ones asserting
that a doctor without consent is refused and that no role can reach both
population and individual data.

What is not real: any connection to a government system. Those exist as PHP
interfaces plus a written statement of what each real adapter would need, which
is deliberate — inventing a BPJS or SATUSEHAT contract produces code that looks
finished and cannot be reused when the real specification arrives.

---

## Other scenarios worth showing

Sign in as `citizen2@example.com` for the counter-example — Siti Nurhaliza, 34,
consistent screening, every dimension low. It demonstrates that the risk engine
is reading the data rather than manufacturing alarm.

The other seeded scenarios (visible to the doctor, or via the API):

| Patient | Scenario |
|---|---|
| Ahmad Fauzi | Cardiovascular risk climbing over a decade |
| Siti Nurhaliza | Strong preventive profile, low across the board |
| Dewi Anggraini | Maternal — low haemoglobin, monitoring intervention in progress |
| Budi Santoso | Diabetes progression (the demo citizen) |
| Rina Marlina | Asthma shaped by local air quality |
| Joko Susilo | Treatment is in place; adherence is the problem |
