# API

Versioned REST under `/api/v1`. Authentication is a Sanctum bearer token.
Every response is `{ data, meta }`, and `meta.data_classification` is
`SYNTHETIC` on every payload built from generated records.

```
Authorization: Bearer <token>
Accept: application/json
```

## Conventions

| | |
|---|---|
| Success | `200` with `{ "data": {...}, "meta": {...} }` |
| Validation failure | `422` with Laravel's error bag |
| Not authenticated | `401` — the client clears its stored token |
| Permission or consent refused | `403`, and the denial is written to `audit_logs` |
| Not found / not yours | `404` |
| Rate limited | `429` |

Rate limits: login 10/min · AI endpoints 20/min · everything else 120/min.

`403` is used for two distinct situations, and the message distinguishes them:
the role lacks the permission, or no active consent covers the data category.

---

## Auth

| Method | Path | Notes |
|---|---|---|
| `POST` | `/auth/login` | `{email, password}` → token + user with permission list |
| `GET` | `/auth/me` | Current user; used to validate a stored token on boot |
| `POST` | `/auth/logout` | Revokes the current token |

```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d '{"email":"citizen@example.com","password":"password"}'
```

---

## Citizen — `patient.read.own` and friends

Every citizen endpoint resolves the patient **from the token**, never from a
parameter. There is no id to tamper with.

| Method | Path | Returns |
|---|---|---|
| `GET` | `/citizen/dashboard` | risk overview, counters, next action, recent events, notifications |
| `GET` | `/citizen/timeline` | lifetime events grouped by year; `?types=`, `?from=`, `?to=` |
| `GET` | `/citizen/health-records` | diagnoses, split active / resolved |
| `GET` | `/citizen/laboratory` | results **and** per-test series for trends; `?panel=`, `?test_code=` |
| `GET` | `/citizen/medications` | prescriptions, active / past, with adherence |
| `GET` | `/citizen/vaccinations` | vaccinations plus a per-vaccine roll-up |
| `GET` | `/citizen/hospital-visits` | encounters |
| `GET` | `/citizen/bpjs` | SYNTHETIC payer membership, utilisation, claims |
| `GET` | `/citizen/profile` | personal details and health identity |
| `GET` | `/citizen/emergency-profile` | break-glass view: active problems + current medication |

### Risk

| Method | Path | Returns |
|---|---|---|
| `GET` | `/citizen/risk` | all applicable dimensions, plus which ones do **not** apply and why |
| `GET` | `/citizen/risk/{dimension}` | one dimension |
| `GET` | `/citizen/risk/{dimension}/explain` | the "Why?" — ranked contributions, protective factors, limits |
| `POST` | `/citizen/risk/refresh` | recompute from current records |

A risk object always carries `contributing_factors`, `protective_factors`,
`missing_information`, `confidence`, `limitations` and `disclaimer`. There is no
response anywhere that returns a risk level without them.

### Governance

| Method | Path | Returns |
|---|---|---|
| `GET` | `/citizen/sharing` | consents with scope, purpose, status, expiry |
| `POST` | `/citizen/sharing` | grant consent |
| `DELETE` | `/citizen/sharing/{consent}` | revoke — effective on the next request |
| `GET` | `/citizen/access-log` | who opened the record, when, which category, under which consent |
| `GET` | `/citizen/corrections` | submitted corrections and the workflow states |
| `POST` | `/citizen/corrections` | dispute a record; it is marked, not hidden |
| `GET` | `/citizen/notifications` | feed |

### AI

| Method | Path | Notes |
|---|---|---|
| `POST` | `/ai/assistant` | `{question}` → grounded answer, or an explicit refusal |
| `GET` | `/ai/assistant/suggestions` | questions this record can actually answer |
| `GET` | `/ai/summary` | plain-language summary of the record |
| `GET` | `/ai/education/{topic}` | general information, not personalised advice |

A refusal is a normal `200` with `grounded: false` and `confidence: 0`. It is an
answer, not an error.

---

## Clinical — consent-gated

Every one of these resolves a patient by id **and** requires an active consent
covering that data category. Each successful read writes a row the patient can
see; each refusal writes an audit row.

| Method | Path | Category checked |
|---|---|---|
| `GET` | `/clinical/dashboard` | — (work queue over consented patients) |
| `GET` | `/clinical/patients` | — (list derived from consent; `?q=` name or health id) |
| `GET` | `/clinical/patients/{id}` | `timeline` — also returns permitted/withheld categories |
| `GET` | `/clinical/patients/{id}/timeline` | `timeline` |
| `GET` | `/clinical/patients/{id}/risk` | `risk` |
| `GET` | `/clinical/patients/{id}/summary` | `summary` — AI clinical summary |
| `GET` | `/clinical/patients/{id}/laboratory` | `laboratory` |
| `GET` | `/clinical/patients/{id}/medications` | `medications` |
| `GET` | `/clinical/patients/{id}/diagnoses` | `diagnoses` |
| `GET` | `/clinical/patients/{id}/visits` | `visits` |
| `GET` | `/clinical/access-log` | the clinician's own trail — the same rows the patient sees |

---

## Government — aggregate only

No response from any of these contains a patient id, a name, or any other
identifier. Counts below the aggregation threshold are returned as `null` with a
`suppressed` flag.

| Method | Path | Returns |
|---|---|---|
| `GET` | `/government/dashboard` | national metrics, disease movement, capacity, risk distribution, AI insight |
| `GET` | `/government/population` | coverage indicators by province |
| `GET` | `/government/disease` | incidence and change by disease and province |
| `GET` | `/government/regions` | province list with headline indicators |
| `GET` | `/government/regions/{region}` | regional intelligence: metrics, environment series, capacity, workforce |
| `GET` | `/government/facilities` | capacity and occupancy |
| `GET` | `/government/medicine` | stock position, critical lines |
| `GET` | `/government/workforce` | density per 100k against target |
| `GET` | `/government/risk` | risk distribution nationally and by region |
| `GET` | `/government/forecast` | straight-line projection, labelled as such |

---

## SENTRA Core

| Method | Path | Returns |
|---|---|---|
| `GET` | `/sentra/overview` | fabric scale, pipeline counts, recent alerts |
| `GET` | `/sentra/data-sources` | every source with status `mock` / `planned` / `connected` and integration notes |
| `GET` | `/sentra/health-graph` | entity and relationship **counts** — shape, never contents |
| `GET` | `/sentra/intelligence` | weighted cross-domain signals |
| `GET` | `/sentra/risk-engine` | engine, dimensions, stored distribution |
| `GET` | `/sentra/alerts` | alerts with contributing signals, recommended actions, linked interventions |
| `PATCH` | `/sentra/alerts/{alert}` | `{status}` — audited |
| `GET` | `/sentra/audit` | full audit trail including denials; `?action=`, `?result=` |

## Shared

| Method | Path | Notes |
|---|---|---|
| `GET` | `/interventions` | patient-scoped ones are hidden from non-clinical roles |
| `GET` | `/interventions/{id}` | with measured outcomes |
| `PATCH` | `/interventions/{id}` | `{status, note}` — audited |
| `GET` | `/health` | unauthenticated liveness; declares the data classification |

---

## Example: a risk object

```json
{
  "dimension": "metabolic",
  "label": "Metabolic",
  "risk_level": "elevated",
  "risk_score": 64,
  "confidence": 92,
  "summary": "Your recent indicators suggest an elevated metabolic risk signal.",
  "recommended_action": "Consider discussing appropriate metabolic screening with a healthcare professional.",
  "limitations": "Calculated from records already present in this account. It is not a diagnostic test for diabetes…",
  "model_version": "sentra-mock-risk-1.0.0",
  "engine": "MockRiskEngine",
  "contributing_factors": [
    { "label": "HbA1c in diabetic range", "detail": "Most recent HbA1c 7.1%.", "weight": 30,
      "evidence_type": "LaboratoryResult", "evidence_id": 412 }
  ],
  "protective_factors": [
    { "label": "Screening up to date", "detail": "Most recent laboratory result is less than a month old." }
  ],
  "missing_information": [],
  "disclaimer": "This is an AI-generated decision-support signal, not a medical diagnosis."
}
```

`evidence_type` and `evidence_id` point at the record that justifies the claim,
so any statement the system makes can be traced back to the row behind it.
