"""Implementation annex for services/level.jac."""

impl RoutedDeliberator.gather {
    # `visit` one node at a time, in the player's chosen order. The queue
    # preserves insertion order, so arrival order == route order, and because
    # each arrival fires Evidence.hand_off the touch record is still produced
    # by movement rather than copied from `self.route`.
    #
    # A route naming an id that isn't on the graph simply visits nothing for
    # that entry -- it cannot fabricate a touch.
    known = {e.source_id: e for e in [-->[?:Evidence]]};
    for sid in self.route {
        if sid in known {
            visit known[sid];
        }
    }
}


impl seed_board -> None {
    for n in [root -->[?:Evidence]] {
        del n;
    }
    for n in [root -->[?:Decision]] {
        del n;
    }
    # Required before any traversal byLLM might route: stale anchors otherwise
    # surface as "NodeAnchor is not a valid reference".
    commit();

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


impl Board.run {
    seed_board();
    report {
        "evidence": [
            {"id": e.source_id, "content": e.content, "verified": e.verified}
            for e in [-->[?:Evidence]]
        ]
    };
}


impl RouteRun.run {
    seed_board();

    # Default itinerary when the player hasn't chosen one (Guided Run).
    itinerary = self.route if self.route else ["E1", "E2", "E3", "E4"];

    here spawn RoutedDeliberator(route=itinerary);
    d = [-->[?:Decision]][-1];

    # Adversary: the agent additionally CLAIMS these. It never touched them,
    # so the gate is about to notice. This is tampering with the claim, never
    # with the record -- touched_ids is untouched by this line.
    if self.inject {
        d.cited_ids = d.cited_ids + self.inject;
    }

    findings = (d spawn ProvenanceGate()).findings;

    grounded_n = len([f for f in findings if f["verdict"] == Verdict.GROUNDED]);
    total = len(d.cited_ids);
    rate = (grounded_n / total) if total > 0 else 0.0;

    overall = Verdict.GROUNDED;
    if total == 0 {
        overall = Verdict.UNSUPPORTED;
    } elif any([f["verdict"] == Verdict.FABRICATED for f in findings]) {
        overall = Verdict.FABRICATED;
    } elif any([f["verdict"] == Verdict.UNVERIFIED for f in findings]) {
        overall = Verdict.UNVERIFIED;
    }

    # One report, emitted last. A walker spawned inside this one leaks its own
    # reports into this stream ahead of ours, so callers read reports[-1].
    report {
        "evidence": [
            {"id": e.source_id, "content": e.content, "verified": e.verified}
            for e in [-->[?:Evidence]]
        ],
        "requested": itinerary,
        "touched": d.touched_ids,
        "cited": d.cited_ids,
        "action": d.action,
        "explanation": d.explanation,
        "verdicts": findings,
        "rate": rate,
        "overall": overall
    };
}
