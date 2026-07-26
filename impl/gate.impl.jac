"""Implementation annex for gate.jac.

No model is called here either. Lookup and set membership only.
"""

impl ProvenanceGate.audit {
    # `here` is the Decision under audit; `self` is this walker. Walker-side
    # ability, so the type in the `with` clause names the NODE type.
    #
    # Each finding is appended to self.findings and then reported from there,
    # so the two channels cannot drift apart: `report` serves a REST caller,
    # `findings` serves a caller that spawned this walker from inside another
    # walker (where reports come back empty).

    # Nothing cited at all. This is its own verdict rather than a vacuous
    # pass: an agent that acted while citing no evidence has not made a
    # groundable claim, and reporting "no fabrications found" for that would
    # be technically true and completely misleading.
    if not here.cited_ids {
        self.findings.append({"id": None, "verdict": Verdict.UNSUPPORTED});
        report self.findings[-1];
        skip;
    }

    # Resolve source_ids back to the Evidence nodes they name.
    #
    # This is a read, and a read is correct HERE -- the rule that traversal
    # must produce the touch record applies to the agent, which is making the
    # record. The gate is checking one that already exists, so it must look
    # things up without disturbing them. Reading is the conservative choice,
    # and the gate could not append to a touch record even if it tried.
    known = {e.source_id: e for e in [root -->][?:Evidence]};

    for cid in here.cited_ids {
        if cid not in here.touched_ids {
            # Cited but never reached. The agent named a source its own
            # traversal never visited. Membership in a closed, pre-existing
            # list -- not an open-ended judgement about whether a claim is
            # true -- which is why this verdict is unambiguous.
            self.findings.append({"id": cid, "verdict": Verdict.FABRICATED});
        } elif isinstance(known.get(cid), Evidence) and known[cid].verified {
            self.findings.append({"id": cid, "verdict": Verdict.GROUNDED});
        } else {
            # Reached, but either not confirmed before the agent ran, or no
            # longer resolvable to a real Evidence node. Both fail closed to
            # UNVERIFIED: the gate never upgrades something to grounded on
            # the strength of what it could not check.
            self.findings.append({"id": cid, "verdict": Verdict.UNVERIFIED});
        }
        report self.findings[-1];
    }
}
