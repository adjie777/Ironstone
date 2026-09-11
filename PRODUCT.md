# Product

## What this is

An intelligence and orchestration layer over health systems that already exist.

## What it is not

It does not replace SATUSEHAT, BPJS/JKN, JMO, hospital SIMRS, SIMPUS, electronic
medical records, laboratory systems, pharmacy systems, or any existing government
application. Those systems hold the records. This one links them into a journey,
turns that journey into explainable signals, and routes those signals to someone
who can act.

If it ever becomes another place where clinical records are authored, it has
failed at what it is for.

---

## One data fabric, three points of view

| | Citizen | Healthcare professional | Government |
|---|---|---|---|
| Question | "Understand my health." | "Understand my patient." | "Understand Indonesia's health." |
| Sees | their own complete record | a consented patient's record | aggregates only |
| Tone | warm, calm, human | clinical, dense, efficient | analytical, strategic |
| Cannot see | anyone else's record | anything without consent | any individual, ever |

Same architecture underneath. Completely different permissions and interfaces.

---

## Product principles

### 1. No universal health score

"Ahmad Health Score = 73" is scientifically weak and encourages exactly the
decisions this system should discourage. Risk is reported across eight
independent dimensions, each with its own confidence and evidence. No column
combining them exists, and a test enforces that.

### 2. Explanation is part of the output, not a feature

Every signal ships with what contributed, what is protective, what is missing,
how confident the calculation is, and what it cannot see. A risk level without
its evidence is never rendered anywhere — the component that displays a signal
also displays its limits.

### 3. Missing information is a result, not a gap

"No recent HbA1c on record" is often the most useful thing the system can say. It
is a first-class part of every assessment and the honest reason confidence is not
higher.

### 4. Never alarm without context

Not "YOU HAVE 82% DIABETES". Instead: "Your recent indicators suggest an elevated
metabolic risk signal" — then why, then what to do, then what this cannot tell
you. The dashboard leads with a word, not a number.

### 5. The citizen owns their record

They see who has access, what each party can see, why, and every time it was
actually opened. They can withdraw access, and they can dispute a record. A
disputed record is marked, not hidden — a clinician may already have acted on it.

### 6. Government sees populations, never people

Enforced structurally: aggregate tables carry no patient key, no role holds both
population and patient permissions, and small cells are suppressed rather than
rounded.

### 7. The loop must close

Data → intelligence → risk → recommendation → **human review** → intervention
with a named owner → measured outcome. A platform that stops at a dashboard has
not changed anything.

### 8. Decision support, never decision making

The system proposes no diagnosis, prescribes nothing, changes no dose. The
clinician remains responsible. This is stated in the clinical summary itself, not
only in documentation.

---

## Language

| Use | Not |
|---|---|
| My Health | Patient Portal |
| Clinical Intelligence | Doctor Dashboard |
| Health Intelligence | Government Surveillance |
| Health Journey | Patient File |
| Risk Signal | Diagnosis / Prediction |
| Decision Support | AI Diagnosis |
| SENTRA Health Core | The Algorithm |

Never: "Government Patient Surveillance", "Universal Health Score", "AI
Diagnosis", "Automatic Medical Decision".

---

## What the prototype demonstrates

The full vertical slice, working end to end on synthetic data:

```
Citizen → health identity → lifetime timeline → AI risk analysis → "why?"
   → recommendation → consent → doctor view → AI clinical summary
   → government aggregate intelligence → SENTRA cross-domain alert
   → intervention with a named owner → measured outcome → audit trail
```

Every step is a real feature backed by a real database and a real API — not a
mockup of one.

## What it deliberately does not demonstrate

Any connection to a real government system. Those exist as interfaces plus a
written statement of requirements. Inventing a BPJS or SATUSEHAT contract would
produce code that looks finished and is worthless when the real specification
arrives — and the wrong parts would be the ones everything above already depends
on.

---

## Who this is for, and what they should conclude

**An investor or stakeholder** should conclude that the concept is coherent and
the hard parts — consent enforcement, explainability, the population/individual
separation, the action loop — have been thought through rather than deferred.

**A clinician** should conclude that the summary would save them time and does
not pretend to practise medicine.

**A government technical reviewer** should conclude that the integration
boundaries are honest, that the privacy properties are structural rather than
promised, and that nothing here claims a connection it does not have.

**A engineer joining the project** should be able to run one command, get a
working system with a coherent dataset, and find the seams where real
integrations go.
