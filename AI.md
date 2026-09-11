# AI architecture

Two independent things are called "AI" here, and keeping them separate matters:

1. **The risk engine** — deterministic, rule-based, no model involved.
2. **The language layer** — explanation, summarisation, question answering.

The risk engine decides *what the signal is*. The language layer only puts it
into words. That split is why an explanation can always be checked against the
data: it is describing a calculation, not producing one.

---

## The seam

```
app/Domain/AI/
  Contracts/AIProviderInterface.php     the only seam to any language model
  Providers/AbstractAIProvider.php      the safety envelope
  Providers/MockAIProvider.php          deterministic, offline

app/Domain/Risk/
  Contracts/RiskEngineInterface.php
  Contracts/RiskDimensionInterface.php
  Data/RiskResult.php  Data/RiskFactorData.php
  Dimensions/…                          8 independent dimensions
  Engines/MockRiskEngine.php
  RiskAssessmentService.php             runs the engine, persists with evidence
```

Nothing outside `app/Domain/AI` knows which provider is in use. Swapping
`MockAIProvider` for a hosted model, or for a government-operated private model,
is one line in `SentraServiceProvider`.

**The prototype runs with no API key and no network access.** That is a design
requirement, not a limitation: a demo that fails when the internet does is not a
demo, and a risk signal that changes between two screens because a model was
sampled twice is worse than no signal.

---

## The risk engine

### Eight independent dimensions

`cardiovascular` · `metabolic` · `respiratory` · `maternal` · `infectious` ·
`preventive` · `medication_adherence` · `general_wellness`

Each implements `RiskDimensionInterface` and answers two questions:

- `appliesTo($patient)` — is this dimension meaningful for this person at all?
  `maternal` requires a recorded pregnancy episode; `medication_adherence`
  requires an active prescription. A dimension that does not apply is reported as
  *not assessed*, never as *low risk* — an absent dimension otherwise reads as
  "no risk here", which is a different and false claim.
- `evaluate($patient)` — a `RiskResult` with level, score, confidence, evidence,
  recommendation and limitations.

### No universal health score

Spec §34, enforced three ways: no composite column exists, a schema test asserts
it, and scores are documented as comparable **only within a dimension**. The UI
repeats it on every risk card.

Combining independent clinical signals into one number is scientifically weak and
invites exactly the decisions this system should not encourage.

### Scoring: diminishing returns on ranked evidence

Contributing factors within a dimension are usually correlated. An HbA1c in the
diabetic range, a fasting glucose in the diabetic range and a diabetes diagnosis
are largely *one finding stated three times*.

Summing their weights saturates the score at 100 and destroys the gradation
between a newly-raised result and a decade of poor control. So the heaviest
factor counts in full and each subsequent one counts for progressively less
(`1.0, 0.6, 0.4, 0.3, 0.25, 0.2, …`). Protective factors are discounted the same
way.

Bands are fixed: `≥70 high`, `≥45 elevated`, `≥25 moderate`, else `low`.

### Confidence is completeness, not certainty

`confidence` answers "how complete and recent is the data behind this?", not "how
sure is the model?". It is derived from how many of the dimension's expected
inputs are present, with a penalty for staleness, and is **capped at 92** — a
decision-support signal never claims to be sure.

The UI says this in the tooltip, because a bare percentage next to a health
signal invites the wrong reading.

### Missing information is a first-class result

`RiskFactorData::missing()` is not an error path. "No recent HbA1c on record" is
frequently the most useful thing this system can tell a clinician, and it is the
honest explanation for why confidence is not higher.

### Determinism

No `rand()`, no sampling, no time-dependence beyond the record dates. The same
patient row always produces the same signal.

`RiskEngineTest::test_the_engine_is_deterministic` runs the engine twice and
asserts score, level and confidence are identical.

---

## The language layer

### The safety envelope

`AbstractAIProvider::envelope()` wraps every response:

```php
[
  'confidence'          => int,
  'missing_information' => array,
  'limitations'         => array,
  'disclaimer'          => 'This is an AI-generated decision-support signal, not a medical diagnosis…',
  'provider'            => 'MockAIProvider',
  'model_version'       => 'sentra-mock-llm-1.0.0',
  'generated_at'        => ISO-8601,
]
```

Applied in the abstract base, so a subclass cannot forget it, and mirrored in the
frontend: the `AIInsight` component renders confidence, missing information,
limitations and disclaimer as part of the frame. There is no code path that shows
a model's answer without them.

`ProvenanceAndAiSafetyTest` asserts the envelope on every provider method.

### The refusal path

`insufficientContext()` returns:

> "I don't have enough verified information in your record to answer that."

with `grounded: false` and `confidence: 0`. The UI renders it as a normal answer,
not an error — because it *is* the correct answer.

Intent is matched against a fixed set of questions the record can actually
support: explain a dimension, what changed over N years, show my history, what to
raise with a clinician. Anything outside that set refuses. There is no free-form
generation path that could invent a medical record.

### What each method does

| Method | Grounded in |
|---|---|
| `generatePatientSummary` | active conditions, medications, most recent contact |
| `generateClinicalSummary` | context, measured deltas, history, encounters, risk signals, missing data, follow-up questions |
| `explainRisk` | the stored `risk_factors` for that assessment |
| `answerCitizenQuestion` | matched intent over the patient's own records |
| `generatePopulationInsight` | aggregate metric movements only |
| `generateHealthEducation` | a fixed library; unknown topics return low confidence and say so |

### Voice

The stored risk `summary` is written in the second person for the person whose
record it is ("Your recent indicators suggest…"). Rendering that to a clinician
about someone else reads wrong, so clinical surfaces lead with the **evidence**
instead — the top contributing factor and its detail. `RiskCard` takes a
`voice` prop; the clinical summary returns `driver`/`driver_detail` rather than
the citizen sentence.

### Medical safety

The system never diagnoses, never prescribes, never changes a dose, and never
issues emergency instructions. The clinical summary states explicitly that it
reorganises existing records, proposes no diagnosis and no treatment, and that
decisions remain with the treating clinician. Citizen-facing medication guidance
always says to speak to the prescriber before changing anything.

Language is calibrated: "Your recent indicators suggest an elevated metabolic
risk signal", never "you have an 82% chance of diabetes". The dashboard leads
with a word — *Monitor*, *Good*, *Needs attention* — not a number.

---

## Replacing the mock provider

Implement `AIProviderInterface` and bind it. Three properties must survive the
swap, or the safety argument in this document stops being true:

1. **The refusal path.** The model must keep saying it does not have enough
   information rather than generating a plausible record. This needs prompt
   design *and* output validation — a model asked to be helpful will invent.
2. **Grounding.** Only records the requesting user is authorised to see may enter
   the context. The context passed is recorded in `ai_analyses.context_used`.
3. **The envelope.** Confidence, missing information, limitations and disclaimer
   are structural, not prose the model is asked to append.

Also decide, before connecting anything: whether patient data may leave the
national boundary at all, what the provider retains, and whether a
government-operated private model is required. That is a policy question, and it
gates the technical one.
