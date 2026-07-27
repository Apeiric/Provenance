"""Beat engine for Level.

Two rules govern everything here.

1. Reactive `has` fields are REBOUND, never mutated. `x = x + [v]` re-renders;
   `x.append(v)` silently does not.
2. A `setTimeout` callback reads the render-time snapshot of reactive state, not
   the latest value. So every scheduled beat computes from values CAPTURED in
   its enclosing call frame (`chosen`, `i`) and assigns absolute values. That is
   why the walk is a self-scheduling step function rather than a loop of
   closures over a mutating index — the loop version reads stale and desyncs.
"""

impl Level.load_board -> None {
    # No model involved -- this is a graph read, so the landing page paints the
    # real evidence instantly rather than waiting on a decision.
    #
    # Guarded: a mount effect that throws takes the whole page down with it and
    # the error boundary then remounts, which loops. A demo must degrade to a
    # usable screen, never to a blank one.
    try {
        result = root spawn Board();
        if result.reports {
            b = result.reports[-1] as dict;
            evidence = b["evidence"] as list[dict];
            note = "four pieces of evidence. each carries a verified flag the agent will never see.";
        }
    } except Exception as e {
        note = "board unavailable — press GUIDED RUN to load it";
    }
}


impl Level.step_walk(chosen: list[str], i: int) -> None {
    if i >= len(chosen) {
        # The walk owns the animation; it decides when the next beat may start.
        finish_walk();
        return;
    }
    # Absolute assignment from captured values -- never `collected + [x]`.
    walkerAt = chosen[i];
    collected = chosen[0 : i + 1];
    setTimeout(lambda { step_walk(chosen, i + 1); }, 760);
}


impl Level.finish_walk -> None {
    # Hand-off between the animation and the network, without clock arithmetic.
    # PENDING is module state, so this reads the CURRENT value rather than the
    # snapshot this closure was created with. If the model is still thinking,
    # the oracle beat simply holds -- which is exactly what it is there for.
    r = PENDING["data"] as dict;
    if not r {
        setTimeout(lambda { finish_walk(); }, 250);
        return;
    }

    # The record the walker actually produced wins over the route we asked for.
    # In free play a route may name a node that is not on the graph; showing the
    # request instead of the record would be a lie.
    # Cast at the boundary: dict values are Any and Jac will not auto-narrow.
    collected = r["touched"] as list[str];
    touched = r["touched"] as list[str];
    cited = r["cited"] as list[str];
    verdicts = r["verdicts"] as list[dict];
    evidence = r["evidence"] as list[dict];
    action = str(r["action"]);
    explanation = str(r["explanation"]);
    rate = float(r["rate"]);
    overall = str(r["overall"]);

    phase = "oracle";
    note = "the claims cross to the model. the verified flags stay behind.";

    ids = r["cited"] as list[str];
    setTimeout(lambda {
        phase = "audit";
        note = "the gate walks the citations. it cannot collect, so it cannot contaminate what it checks.";
        step_audit(ids, 0);
    }, 1600);
}


impl Level.step_audit(ids: list[str], i: int) -> None {
    # Constant velocity, identical dwell at every stop. The agent eased and
    # arced; the auditor does not. The rigidity is the argument -- do not
    # "improve" this into something graceful.
    if i >= len(ids) {
        auditAt = "";
        phase = "score";
        note = "the gate has answered. same code, same answer, every time.";
        busy = False;
        return;
    }
    auditAt = ids[i];
    setTimeout(lambda { step_audit(ids, i + 1); }, 460);
}


impl Level.run_level(chosen: list[str], inject: list[str]) -> None {
    busy = True;
    phase = "board";
    note = "four pieces of evidence. each carries a verified flag the agent will never see.";
    collected = [];
    touched = [];
    cited = [];
    verdicts = [];
    walkerAt = "root";
    auditAt = "";
    overall = "";
    action = "";
    explanation = "";
    rate = 0.0;
    PENDING["data"] = None;

    # The walk starts immediately and the server call is fired in the same
    # breath, so real LLM latency is spent inside the animation instead of
    # behind a spinner.
    setTimeout(lambda {
        phase = "walk";
        note = "the agent walks. every node it enters hands itself to the walker — the record is written by movement.";
        step_walk(chosen, 0);
    }, 820);

    result = root spawn RouteRun(route=chosen, inject=inject);

    if result.reports {
        # Park it; finish_walk() picks it up once the animation has landed, so
        # the two never fight over `collected`.
        PENDING["data"] = result.reports[-1];
    } else {
        phase = "idle";
        note = "no response from the walker.";
        busy = False;
    }
}


impl Level.start_guided -> None {
    mode = "guided";
    route = ["E1", "E2", "E3", "E4"];
    injectText = "";
    run_level(["E1", "E2", "E3", "E4"], []);
}


impl Level.start_free -> None {
    mode = "free";
    phase = "walk";
    busy = False;
    route = [];
    collected = [];
    touched = [];
    cited = [];
    verdicts = [];
    walkerAt = "root";
    auditAt = "";
    overall = "";
    action = "";
    explanation = "";
    rate = 0.0;
    injectText = "";
    note = "your turn. click nodes to choose a route, then commit. the gate is correct whichever path you take.";
}


impl Level.toggle_node(nid: str) -> None {
    if mode != "free" or phase != "walk" or busy {
        return;
    }
    if nid == "root" or nid == "decision" {
        return;
    }
    if nid in route {
        next = [r for r in route if r != nid];
    } else {
        next = route + [nid];
    }
    route = next;
    collected = next;
    walkerAt = next[-1] if next else "root";
    note = "route: " + (",".join(next) if next else "(empty)") + " — commit when ready.";
}


impl Level.commit_free -> None {
    inject = [injectText] if injectText else [];
    run_level(route, inject);
}


impl Level.reset -> None {
    phase = "idle";
    mode = "guided";
    busy = False;
    route = [];
    collected = [];
    touched = [];
    cited = [];
    verdicts = [];
    walkerAt = "root";
    auditAt = "";
    overall = "";
    action = "";
    explanation = "";
    rate = 0.0;
    injectText = "";
    note = "";
}
