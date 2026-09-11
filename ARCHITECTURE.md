# Architecture

SENTRA Health is a modular monolith: one Laravel application, one database, a
domain layer split by responsibility, and a React SPA that talks to it over a
versioned REST API. There are no microservices, and none are needed at this
scale — but the domain boundaries are drawn where the seams would be if they
were ever required.

## The layer this platform occupies

```
   EXISTING HEALTH SYSTEMS
   hospital EMR · laboratory · pharmacy · payer · immunisation registry
              │
              │  (today: synthetic generators. future: authorised adapters)
              ▼
   ┌──────────────────────────────────────────────────────────────┐
   │  IDENTITY + INTEROPERABILITY                                  │
   │  IdentityProviderInterface · HealthDataProviderInterface      │
   │  PayerDataProviderInterface                                   │
   └──────────────────────────────────────────────────────────────┘
              ▼
   ┌──────────────────────────────────────────────────────────────┐
   │  SENTRA HEALTH DATA FABRIC                                    │
   │  normalised relational store · provenance on every record     │
   └──────────────────────────────────────────────────────────────┘
              ▼
   ┌──────────────────────────────────────────────────────────────┐
   │  LONGITUDINAL HEALTH GRAPH                                    │
   │  health_events spine + typed detail records                   │
   └──────────────────────────────────────────────────────────────┘
              ▼
   ┌──────────────────────────────────────────────────────────────┐
   │  HEALTH INTELLIGENCE                                          │
   │  RiskEngineInterface (8 dimensions) · AIProviderInterface      │
   └──────────────────────────────────────────────────────────────┘
              ▼
   ┌──────────────────────────────────────────────────────────────┐
   │  DECISION SUPPORT                                             │
   │  explainable signal: evidence · confidence · what is missing   │
   └──────────────────────────────────────────────────────────────┘
              ▼
        HUMAN ACTION  ──►  INTERVENTION (named owner, status)
              ▼
           OUTCOME  (measured against a baseline)
              ▼
        LEARNING LOOP  ──►  back into the intelligence layer
```

The platform replaces nothing. It consumes what already exists and adds the
layer above it: linkage, explanation, and a route from a signal to a person who
can act on it.

## Request path

```
Browser (React SPA)
   │  fetch /api/v1/... with a Sanctum bearer token
   ▼
routes/api.php ──► ApiController (base)
   │                 ├─ requirePermission()   role permission, fails closed
   │                 ├─ consentedPatient()    active consent for THIS category
   │                 └─ AuditRecorder         writes access log + audit row
   ▼
Domain service (HealthDataProvider / RiskEngine / AIProvider / ConsentGate)
   ▼
Eloquent models ──► SQLite (dev) / PostgreSQL (target)
   ▼
API Resource ──► JSON { data, meta: { data_classification: SYNTHETIC } }
```

Authorisation is not per-action boilerplate. It lives in the base controller, so
a new endpoint cannot forget to check permission, check consent, or write an
audit row — the three things that would each be invisible if omitted.

## Directory layout

```
app/
  Domain/
    AI/          Contracts/ Providers/          the only seam to any language model
    Audit/       AuditRecorder                  two trails: citizen-facing + operator
    Consent/     ConsentGate                    the single "may they read this?" answer
    Health/      Contracts/ Providers/          clinical reads (future: SATUSEHAT)
    Identity/    Contracts/ Providers/          health identity (future: Dukcapil)
    Patient/     Contracts/ Providers/          payer data (future: BPJS/JKN)
    Risk/        Contracts/ Data/ Dimensions/ Engines/   8 independent dimensions
  Http/
    Controllers/Api/V1/    ApiController + Citizen/ Clinical/ Government/ Sentra/
    Requests/              form requests, validation at the boundary
    Resources/             serialisation, provenance attached
  Models/                  37 Eloquent models
  Providers/SentraServiceProvider.php    ← every integration binding, one file

resources/
  css/app.css              design tokens, light + dark, risk scale
  js/
    components/ui/         primitives (Button, Card, Badge, Meter, Alert…)
    components/domain/     badges, risk, timeline, ai, charts
    layouts/               PortalLayout — one shell, four navigations
    lib/                   api client, auth context, formatters
    pages/                 public · citizen · clinical · government · sentra

database/
  migrations/              6 domain migrations, 35 tables
  seeders/                 roles, reference data, synthetic population, risk, SENTRA
  seeders/Support/         SyntheticPatientBuilder — every generated record
tests/
  Feature/                 auth, consent, risk, provenance, AI safety
  Support/                 fixtures
```

## Why a modular monolith

Splitting this into services now would buy distributed tracing and network
failures, and cost the thing that actually matters here: a single transaction
across consent, audit and clinical read. The domain directories mark the seams.
If the risk engine ever needs to scale independently, it already sits behind
`RiskEngineInterface` with no Eloquent leaking through the boundary.

## The integration seam

`app/Providers/SentraServiceProvider.php` is the whole of it:

```php
$this->app->bind(IdentityProviderInterface::class,   MockIdentityProvider::class);
$this->app->bind(HealthDataProviderInterface::class, MockHealthDataProvider::class);
$this->app->bind(PayerDataProviderInterface::class,  MockBPJSProvider::class);
$this->app->bind(AIProviderInterface::class,         MockAIProvider::class);
$this->app->bind(RiskEngineInterface::class,         MockRiskEngine::class);
```

Replacing a mock with a real adapter changes this file and nothing else. No
controller, page or test knows which implementation is running. See
`INTEGRATION.md` for what each real adapter would require.

## The timeline spine

Rendering a lifetime health journey from nine record types is either a nine-way
UNION on every request, or a projection. This uses a projection:

```
patients ──1:N──► health_events ──polymorphic──► diagnoses
                        │                        laboratory_results
                        │                        prescriptions
                        │                        vaccinations
                        │                        hospital_visits
                        └──► healthcare_facilities
```

`SyntheticPatientBuilder` is the only writer of clinical data, and it writes both
sides. That makes timeline completeness a property of construction rather than a
convention someone must remember.

## Risk architecture

```
RiskEngineInterface
   └── MockRiskEngine (deterministic, rule-based)
         ├── CardiovascularDimension
         ├── MetabolicDimension
         ├── RespiratoryDimension
         ├── MaternalDimension            appliesTo() → recorded pregnancy only
         ├── InfectiousDimension
         ├── PreventiveDimension          scored as a GAP, not a disease risk
         ├── MedicationAdherenceDimension appliesTo() → has active prescription
         └── GeneralWellnessDimension     lifestyle only, NOT a roll-up

each dimension → RiskResult { level, score, confidence, factors[], limitations }
                                              │
                                    contributing / protective / missing
```

Two properties are enforced rather than intended:

- **Determinism.** No `rand()` anywhere. The same record always produces the same
  signal, which is what makes an explanation checkable against the data.
- **No cross-dimension arithmetic.** Scores are comparable only within a
  dimension. `RiskEngineTest` asserts that no composite score column exists.

Within a dimension, contributing factors are combined with **diminishing
returns** rather than summed. An HbA1c in the diabetic range, a fasting glucose
in the diabetic range and a diabetes diagnosis are largely one finding stated
three times; adding them outright saturates the score at 100 and destroys the
gradation between a newly-raised result and a decade of poor control.

## Privacy architecture

```
CITIZEN            role: patient.read.*    ── own record only, resolved from the token
CLINICAL           role: patient.read.assigned
                     └── AND active consent covering the data category
                     └── AND every read writes data_access_logs (citizen-visible)
GOVERNMENT         role: population.read   ── reads aggregate tables only
SENTRA             role: sentra.read       ── aggregate + cross-domain signals
```

The separation is structural, not a UI convention:

1. Aggregate tables (`population_metrics`, `disease_trends`, `workforce_metrics`)
   carry **no patient foreign key**. There is no join path from a government
   screen to an individual.
2. **No role holds both** `population.read` and any `patient.read.*`. A test
   asserts this over the seeded role matrix.
3. Counts below the aggregation threshold are **suppressed**, not rounded — a
   count of one in a region is a person, not a statistic.

## Frontend

React 19 + TypeScript, React Router, TanStack Query, Tailwind v4 with
CSS-variable design tokens, hand-written shadcn-style primitives.

Portal page modules load lazily, so signing in as a citizen never downloads the
government charting code:

```
main            333 kB   shell, router, auth, primitives
charts          419 kB   recharts — only on pages that draw
government       21 kB
records          18 kB
sentra           17 kB
clinical         14 kB
```

Every data-backed page goes through one `<Query>` component, so loading, failure
and permission-denied look identical across four portals. A 403 renders as a
deliberate boundary ("Access not permitted"), not as an error.
