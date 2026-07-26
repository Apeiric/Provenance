"""Provenance -- the gate.

Grades a Decision by comparing what the agent said it used against what it
actually reached, and against what was verified before it ran.

No model is called in this file, and none ever should be. That is the whole
reason the project is not another model grading a model's honesty, and it is
the file to point at on stage.

The claim is meant to be checkable rather than trusted, so the phrase that
would delegate to a model is deliberately absent from this file and its
annex -- including from these comments. Grepping this file and
impl/gate.impl.jac for that phrase returns nothing, which is a stronger
demonstration than any sentence here could be.

Everything below is lookup and set membership. Given the same graph it returns
the same verdict every time, which is precisely what an agent cannot promise
about its own reasoning.

ProvenanceGate deliberately does NOT inherit EvidenceCollector. Verified in
task 3: because Evidence.hand_off keys on that base, the gate is structurally
incapable of appending to any touch record, even if it traverses Evidence
nodes. The auditor cannot contaminate what it audits, and that is enforced by
the type system rather than by remembering to be careful.

Bodies live in impl/gate.impl.jac.
"""

import from models { Evidence, Decision }


enum Verdict: str {
    # `: str` makes the members genuinely str instances, so a verdict drops
    # straight into a report, a print, or a JSON body with no `.value`.
    GROUNDED = "grounded",
    UNVERIFIED = "unverified",
    FABRICATED = "fabricated",
    UNSUPPORTED = "unsupported"
}


walker ProvenanceGate {
    # `findings` exists because a walker spawned INSIDE another walker comes
    # back with an empty `reports` list -- verified, and it fails as an
    # IndexError rather than anything descriptive. Walker fields do survive
    # the spawn, so this is the in-process return channel. `report` is kept
    # alongside it so the gate still works as a REST endpoint on its own.
    has findings: list[dict] = [];

    can audit with Decision entry;
}
