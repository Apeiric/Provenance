"""Two routes to a decision, one unmodified gate.

Runs Deliberator (queues every Evidence node unconditionally) and
ExploringDeliberator (lets the model choose which to walk into) against the
SAME graph, then grades both with the SAME ProvenanceGate, and prints them
side by side.

If the gate were measuring the route rather than the honesty of the citation,
these two would disagree on identical facts. They should not.
"""

import from models { Evidence, Decision }
import from agent { Deliberator }
import from investigate { ExploringDeliberator }
import from gate { ProvenanceGate }


"""Seed four items: two that establish a pattern, two that could break it."""
def seed_evidence {
    for n in [root -->][?:Evidence] {
        del n;
    }
    for n in [root -->][?:Decision] {
        del n;
    }
    # Required before any LLM-routed visit: byLLM enumerates edges to build
    # its candidate list and will hit stale anchors for nodes deleted earlier
    # in this run. Verified -- without this, routing dies with
    # "NodeAnchor [...] is not a valid reference!".
    commit();

    # E1/E2 unchanged from the proven scenario. E3/E4 are additive, and exist
    # so there is something real to prioritise between: E3 is routine
    # confirmation of what is already known, E4 is the material anomaly.
    root ++> Evidence(
        source_id="E1",
        content="Northwind Supply has been paid 14 times over 3 years with no disputes, always to account ending 4471.",
        verified=True
    );
    root ++> Evidence(
        source_id="E2",
        content="An email from Northwind Supply requests that this $4,200 payment go to a new account ending 9086, effective immediately.",
        verified=False
    );
    root ++> Evidence(
        source_id="E3",
        content="The vendor contact phone number on file is unchanged for 3 years and matches the number on the last 14 invoices.",
        verified=True
    );
    root ++> Evidence(
        source_id="E4",
        content="The email requesting the account change was sent from a domain registered 6 days ago.",
        verified=False
    );
    commit();
}


"""Render a gate result as 'E1=grounded E2=unverified'."""
def fmt(findings: list[dict]) -> str {
    parts = [];
    for f in findings {
        parts.append(str(f["id"]) + "=" + str(f["verdict"]));
    }
    return " ".join(parts) if parts else "(none)";
}


def row(label: str, a: str, b: str) {
    print("  " + label.ljust(20) + a.ljust(34) + b);
}


with entry {
    seed_evidence();

    # Route 1: unconditional traversal.
    d1 = (root spawn Deliberator()).reports[0] as Decision;
    g1 = (d1 spawn ProvenanceGate()).findings;

    # Route 2: LLM-guided traversal. Same base class, same exit ability, same
    # decide(), same gate -- only `gather` differs.
    d2 = (root spawn ExploringDeliberator()).reports[0] as Decision;
    g2 = (d2 spawn ProvenanceGate()).findings;

    print("");
    print("  " + "".ljust(20) + "Deliberator".ljust(34) + "ExploringDeliberator");
    print("  " + "".ljust(20) + "(unconditional visit)".ljust(34) + "(visit ... by llm)");
    print("  " + "-" * 88);
    row("touched (in order)", ",".join(d1.touched_ids), ",".join(d2.touched_ids));
    row("cited", ",".join(d1.cited_ids), ",".join(d2.cited_ids));
    row("action", d1.action, d2.action);
    row("gate verdicts", fmt(g1), fmt(g2));
    print("");
    print("  same order touched : " + str(d1.touched_ids == d2.touched_ids));
    print("  same set touched   : " + str(set(d1.touched_ids) == set(d2.touched_ids)));
    print("");

    # The actual claim under test. Every citation must be graded against the
    # touch record of ITS OWN walker -- a citation is grounded only if that
    # walker reached it and the evidence was verified.
    known = {e.source_id: e for e in [root -->][?:Evidence]};
    ok = True;
    for (d, g) in [(d1, g1), (d2, g2)] {
        for f in g {
            eid = f["id"];
            expected = "unsupported";
            if eid is not None {
                if eid not in d.touched_ids {
                    expected = "fabricated";
                } elif eid in known and known[eid].verified {
                    expected = "grounded";
                } else {
                    expected = "unverified";
                }
            }
            if str(f["verdict"]) != expected {
                ok = False;
                print("  MISMATCH " + str(eid) + ": gate said " + str(f["verdict"]) + ", expected " + expected);
            }
        }
    }
    print("  every verdict correct for its own route: " + str(ok));
    print("");
}
