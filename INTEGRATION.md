# Integration

**Nothing in this prototype connects to a real system.** Not SATUSEHAT, not
BPJS/JKN, not Dukcapil, not any hospital, laboratory or pharmacy.

That is deliberate, and it is the most important engineering decision in the
project. An AI-assisted build will happily produce plausible-looking endpoint
paths, resource names and field lists for a government API it has never seen.
That code looks finished, passes review, and is worthless — because when the
real specification arrives, none of it matches, and the wrong parts are the ones
already relied upon by everything above them.

So the external systems exist here as **interfaces plus a written statement of
what a real adapter would need**. The interfaces are real and used; the contracts
behind them are explicitly unknown.

---

## What exists today

| Interface | Mock implementation | Would become |
|---|---|---|
| `IdentityProviderInterface` | `MockIdentityProvider` | Dukcapil-backed identity resolution |
| `HealthDataProviderInterface` | `MockHealthDataProvider` | SATUSEHAT-backed clinical reads |
| `PayerDataProviderInterface` | `MockBPJSProvider` | BPJS/JKN membership and utilisation |
| `AIProviderInterface` | `MockAIProvider` | Hosted or government-operated private model |
| `RiskEngineInterface` | `MockRiskEngine` | A validated clinical risk model |

All five are bound in one file: `app/Providers/SentraServiceProvider.php`.
Swapping an implementation is a one-line change there. No controller, page or
test knows which one is running.

---

## Before writing any adapter

For each system below, these must be established **first** — none of them is a
software task, and no amount of code substitutes for them:

1. **Legal basis.** What law or regulation permits this data to flow to this
   platform, for this purpose, for this population?
2. **Authorisation.** Who grants access, under what agreement, with what audit
   obligations, and what is the revocation path?
3. **Credentials and environment.** Sandbox before production. Real credentials,
   real rate limits, real error semantics.
4. **The actual specification.** Retrieved from the operator, versioned, and read
   — not inferred from a blog post, a screenshot, or a language model.
5. **Identity matching rules.** How a person in the source system is proven to be
   the same person here, and what happens when the match is ambiguous.
6. **Data residency and retention.** What may be stored here, for how long, and
   what must remain in the source system and be fetched on demand.

---

## SATUSEHAT (clinical data)

**Status: not connected. Contract unknown.**

*What this platform would need*

- Longitudinal clinical records for a consented individual: conditions,
  encounters, observations (laboratory and vitals), medication, immunisation.
- A stable per-record identifier so provenance can be recorded and a record can
  be re-fetched or reconciled later.
- The originating facility for each record, for the provenance display.
- A timestamp distinguishing when the event happened from when it was recorded.

*What must be researched before implementing*

- The resource model and profiles actually in use, and their versions.
- Authentication, token lifetime and refresh semantics.
- Pagination, incremental sync and change-detection.
- Whether history is retrievable in bulk or only per-encounter.
- Error and partial-response behaviour, and rate limits.

*What should be stored here versus fetched on demand*

Store the projection needed to render a timeline and compute risk, with
provenance. Do not mirror the source of truth. Clinical corrections must flow
back to the originating system — this platform is a reader, not a registry.

*Prototype note*

`MockHealthDataProvider` reads this application's own tables. It does **not**
imitate any external shape, because a mock shaped like a guess is worse than a
mock shaped like nothing: it invites downstream code to depend on the guess.

---

## BPJS / JKN (payer data)

**Status: not connected. Field names in this prototype are invented.**

Every payer field in this codebase — `membership_number_mock`,
`membership_class`, `segment`, `cost_category` — is a plausible prototype shape
and **must not be treated as a BPJS contract**. Payer payloads are labelled
`SYNTHETIC BPJS/JKN DATA` at the API boundary and in the UI.

*What this platform would need*

- Membership status and effective dates.
- Utilisation history: encounters, referrals, pharmacy claims.
- Cost categories at a level appropriate for population analysis.
- A clear statement of which fields may be shown to the member themselves.

*What must be researched*

- The real API surface, authentication and per-endpoint authorisation scope.
- Which fields are permitted for display to the member, to a clinician, and in
  aggregate analysis — these are three different permissions.
- Claim lifecycle states and their meaning.
- Whether utilisation may be used for risk analysis at all, and under what basis.

---

## Dukcapil (identity)

**Status: not connected. No NIK is generated, stored, or accepted anywhere.**

`health_identities.national_id_mock` is deliberately formatted as
`MOCK-NID-00000001` — not NIK-shaped — so a synthetic identifier can never be
mistaken for a real one or accidentally submitted to a real system.

*What this platform would need*

- Verification that a claimed identity belongs to the person presenting it.
- A stable internal health identifier that is **not** the national identifier, so
  the national number does not propagate through every downstream table.

*What must be researched*

- The lawful basis and approval process for identity verification.
- The verification mechanism and its failure and ambiguity semantics.
- Storage rules: almost certainly the national identifier should never be stored
  here at all, only used transiently to establish a link.

---

## Hospital systems (SIMRS), laboratories, pharmacies

**Status: not connected.**

These are many systems, not one. Realistically this means an ingestion layer per
vendor or per facility, not a single adapter.

*What would be needed*

- Per-facility onboarding: agreement, credentials, field mapping, test data.
- A canonical mapping to this platform's record types, with the mapping itself
  versioned and auditable.
- Reconciliation for duplicates and corrections.
- Dispensing data for adherence, which is what makes the medication dimension
  meaningful rather than a guess.

---

## Environmental, population and cross-ministry data

**Status: mock or planned.** Visible on the SENTRA data sources screen with an
explicit status per source.

The dengue demonstration combines health, environment, infrastructure and
population signals. It is labelled `SYNTHETIC CROSS-MINISTRY DEMONSTRATION` on
every screen it appears on, and its stated limitation says plainly that the
relationship is correlational and no causal claim is made.

*What would be needed*

- A shared regional key agreed across ministries. Without one, cross-domain
  correlation is not possible at all — this is the first blocker, not a detail.
- Data-sharing agreements per domain.
- Agreed update cadence, so a signal's age is known.

---

## Adding a real adapter

1. Implement the existing interface. Do not change it to fit one vendor; if it
   genuinely does not fit, change it deliberately and update every implementation.
2. Keep the mock. It is what the test suite and local development run against.
3. Map the external shape to this platform's records **inside the adapter**.
   Nothing above the interface should learn a vendor's field names.
4. Populate the provenance block honestly: real source system, real record id,
   real recorded-at, and a verification status that reflects what the source
   actually asserts.
5. Bind the adapter in `SentraServiceProvider`, behind configuration, so it can
   be switched off without a deploy.
6. Add contract tests against the sandbox. Unit tests against a mock prove only
   that the mock is consistent with itself.
