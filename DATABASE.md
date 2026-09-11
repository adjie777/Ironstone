# Database

35 tables across six domain migrations. Written to be PostgreSQL-compatible and
run on SQLite for local development.

## Portability

The target is PostgreSQL. Local development uses SQLite because the machine this
was built on has no `pdo_pgsql` driver and no Postgres server, and standing one
up buys the demo nothing.

To keep the schema portable, the migrations avoid everything that would tie them
to one engine:

- **No database `ENUM` types.** Enumerated values are `string` columns validated
  in the model and request layers. Postgres check constraints and MySQL enums
  both make later value changes a migration; a string plus validation does not.
- **No `after()` column positioning** (MySQL-only).
- **No raw SQL.** Every query goes through the query builder or Eloquent.
- **`json` columns**, which map to `jsonb` on Postgres and `text` on SQLite.
- **Decimals with explicit precision** for anything numeric that is compared.

Switching engine is a `.env` change plus `php artisan migrate:fresh --seed`:

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=sentra
DB_USERNAME=sentra
DB_PASSWORD=...
```

**Not yet verified against a live PostgreSQL instance.** The schema is written to
be compatible; nobody has run it there. Treat that as an open item, not a claim.

---

## The provenance contract

Every clinical record carries the same block. Spec §32: no health fact is shown
without being traceable to a source.

| Column | Type | Meaning |
|---|---|---|
| `source_system` | string | `SYNTHETIC_HOSPITAL_EMR`, `SYNTHETIC_LAB_NETWORK`, … |
| `source_record_id` | string | e.g. `LAB-000923` — re-fetch and reconciliation key |
| `recorded_at` | timestamp | when the *source* recorded it, distinct from when it happened |
| `verification_status` | string | `verified` / `unverified` / `self_reported` / `disputed` |
| `data_confidence` | string | `high` / `medium` / `low` |
| `provenance` | json | provider, ingest path, notes |

Carried by: `health_events`, `diagnoses`, `laboratory_results`, `prescriptions`,
`vaccinations`, `hospital_visits`, `bpjs_records`, `insurance_claims`.

Note the distinction between **verification** and **confidence**. A pre-2012
paper immunisation record transcribed into a registry is *verified* by that
registry but held at *medium* confidence. Conflating the two would make every
patient over 35 look unvaccinated.

---

## Tables by group

### Identity and access
`users` · `roles` · `permissions` · `permission_role` · `patients` ·
`health_identities` · `healthcare_professionals`

`health_identities` holds `national_id_mock` and `health_id_mock`. The former is
formatted `MOCK-NID-00000001` — deliberately **not** NIK-shaped, so a synthetic
identifier cannot be mistaken for a real one.

### Geography and supply
`regions` (self-referencing: country → province → regency) ·
`healthcare_facilities` · `medicine_stocks` · `workforce_metrics`

### Clinical (longitudinal)
`health_events` · `diagnoses` · `symptoms` · `laboratory_results` ·
`medications` · `prescriptions` · `vaccinations` · `hospital_visits` ·
`lifestyle_factors`

### Payer (synthetic)
`bpjs_records` · `insurance_claims`

### Environment
`environmental_signals`

### Intelligence
`risk_assessments` · `risk_factors` · `ai_analyses`

### Action loop
`interventions` · `outcomes`

### Governance
`consents` · `data_access_logs` · `data_corrections` · `audit_logs` ·
`notifications_feed`

`notifications_feed` rather than `notifications`, to leave the conventional
Laravel notifications table name free.

### Population aggregates
`population_metrics` · `disease_trends`

These carry **no patient foreign key**. That is what makes "government cannot
reach an individual" a property of the schema rather than a promise.

### SENTRA core
`sentra_data_sources` · `sentra_signals` · `sentra_alerts`

---

## The timeline spine

```
patients ──1:N──► health_events
                     │  subject_type / subject_id (polymorphic)
                     ├──► diagnoses
                     ├──► laboratory_results
                     ├──► prescriptions
                     ├──► vaccinations
                     └──► hospital_visits
```

Indexed on `(patient_id, event_date)` and `(subject_type, subject_id)`. A
lifetime timeline is one indexed query rather than a nine-way UNION, and the
detail record is one hop away when a person opens an entry.

---

## Risk model

```
patients ──1:N──► risk_assessments   (one row per patient PER DIMENSION)
                       ├──1:N──► risk_factors   kind: contributing | protective | missing
                       └──1:N──► interventions ──1:N──► outcomes
```

There is **no composite score column anywhere** — no `health_score`, no
`overall_score`. `RiskEngineTest::test_there_is_no_universal_health_score_anywhere_in_the_schema`
inspects the live column listing and fails if one appears. It is enforced as a
schema test rather than a code convention because the temptation to add one
arrives later, from someone else.

`risk_factors.evidence_type` / `evidence_id` point at the record that justifies
the factor, so a claim can always be traced to the row behind it.

---

## Consent

```
patients ──1:N──► consents { grantee_type, grantee_id, scope[], purpose, status, expires_at }
                      │
                      └── referenced by data_access_logs.consent_id
```

`scope` is a JSON array of data categories. A read is authorised only when an
active consent covers the specific category being read — checked at read time,
never cached into a session.

---

## Seeded dataset

`php artisan migrate:fresh --seed` produces:

| | |
|---|---|
| Citizens | 50 (6 hand-scripted scenarios + 44 generated) |
| Timeline events | 736 |
| Laboratory results | 621 |
| Vaccinations | 500 |
| Risk assessments | 314 across 993 evidence factors |
| Regions | 19 (1 country, 5 provinces, 13 regencies) |
| Facilities | 39 |
| Environmental signals | 570 (6-month history per region) |
| Medicine stock lines | 495 |
| Population metrics | 114 · disease trends 133 · workforce 76 |
| SENTRA sources / signals / alerts | 8 / 4 / 2 |

Generation is **deterministic** — fixed `mt_srand` seeds and no `rand()` in the
risk engine — so a rebuild produces the same dataset and the same signals. That
is what makes the demo self-consistent between screens.

Two invariants the generator enforces for all data:

1. Every clinical write also projects a `health_events` row.
2. No record is dated in the future. Scenario series use fixed month/day pairs
   per year, so the most recent entry can land after today depending on when the
   seeder runs; anything ahead of now is pulled back to yesterday.
