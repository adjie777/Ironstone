# Roadmap

## Where this stands

The vertical slice works end to end on synthetic data: citizen → timeline → risk
→ explanation → consent → clinician → population aggregate → cross-domain alert →
intervention → outcome → audit. 34 tests pass, covering the security and safety
claims specifically.

What follows is ordered by what actually unblocks the next thing, not by what is
most fun to build.

---

## Immediate — before showing this to anyone technical

**1. Verify the schema on PostgreSQL.** The migrations are written to be
portable and have never run against a live Postgres instance. That is an open
item, not a claim. One afternoon.

**2. A browser test for the demo path.** The walkthrough was verified manually.
Playwright covering login → risk → why → doctor → government would stop the demo
breaking silently.

**3. Accessibility pass.** Keyboard navigation, focus order, contrast
verification against WCAG AA, screen-reader labels on the charts. A national
health platform has a higher bar here than most products, and it has not been
measured.

**4. Indonesian localisation.** The interface is English-only. For the intended
audience that is a real gap, not a nicety. The copy is deliberately plain, which
helps, but every string needs extracting.

---

## Near term — making the prototype defensible

**5. Clinical review of the risk model.** The dimensions are plausible and
internally consistent. They are **not** validated against any clinical guideline
or population. Before this is shown as anything more than an architecture demo, a
clinician should review the thresholds, the weights and — most importantly — the
language.

**6. Replace the rule-based engine where a validated model exists.** Framingham,
QRISK and similar are published and validated. `RiskEngineInterface` exists so
they can be dropped in per dimension. Where no validated model exists, the
rule-based engine should stay and say so.

**7. The correction workflow's other half.** A citizen can dispute a record and
it is marked. Nobody can currently review it — `correction.review` exists as a
permission with no screen behind it.

**8. Consent granting from the UI.** The API supports granting; the interface only
supports viewing and revoking. Revocation was prioritised because it is the one a
person needs urgently.

**9. Notifications that are actually triggered.** They are seeded, not generated.
A changed risk signal should raise one.

---

## Medium term — the integration work

Each of these is gated on things that are not software. See `INTEGRATION.md`.

**10. Identity.** The first real integration, because everything downstream
depends on knowing that two records belong to one person. Needs a legal basis, a
verification mechanism, and a decision — almost certainly — that the national
identifier is never stored here.

**11. One clinical source, end to end.** Not a broad SATUSEHAT programme: one
facility, one record type, real credentials, real error semantics, real
reconciliation. Everything learned there changes the plan for the rest.

**12. Dispensing data.** The medication adherence dimension is currently inferred
from synthetic dispensing intervals. Real pharmacy data is what makes it
meaningful rather than a guess.

**13. Environmental and cross-ministry feeds.** The blocker here is not an API —
it is an agreed regional key across ministries. Without one, cross-domain
correlation is not possible at all.

---

## Longer term — the architecture already anticipates this

**14. Ingestion at scale.** Queued jobs, incremental sync, reconciliation,
duplicate resolution. `QUEUE_CONNECTION` is `sync` today.

**15. Facility onboarding as a product.** Many source systems, not one. Field
mapping needs to be data, versioned and auditable, not code.

**16. Population analytics beyond counting.** Cohorts, stratification, geographic
clustering — with the aggregation floor enforced in the query layer rather than
per endpoint.

**17. Other SENTRA domains.** Education, social protection, food, employment.
The architecture supports them; only health is modelled in depth, and the
cross-ministry demonstration is explicitly labelled as such.

---

## Production readiness — none of this is started

Everything in the "Not done" table of `SECURITY.md`: encryption at rest, key
management, TLS, penetration testing, a data-protection impact assessment,
retention enforcement, backups with a tested restore, MFA, secure hosting.

Also unstarted: queue workers and supervision, monitoring and alerting, error
tracking, structured logging, a deployment pipeline, and a load profile of any
kind. Nobody has measured what this does under concurrent use.

---

## Things deliberately not planned

**A universal health score.** Not a backlog item. It is refused on the merits,
and a test enforces its absence.

**Autonomous clinical action.** The system proposes; a human decides. Removing
that step changes what the product is.

**A god-mode administrative screen.** No screen anywhere lists all citizen
records. `SYSTEM_ADMIN` is development-only and labelled as such.

**Microservices.** Not until something actually needs to scale independently.
The domain boundaries mark where the seams would be.
