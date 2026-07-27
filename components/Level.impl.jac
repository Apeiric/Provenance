"""Beat engine for Level.

Pacing is deliberately slow. The point of this screen is comprehension, not
spectacle -- each beat has to sit on screen long enough for someone who has
never seen it to read the claim and register what changed. A run takes about
eighteen seconds, and the real model latency (~5s) disappears inside it.

Two rules govern the code.

1. Reactive `has` fields are REBOUND, never mutated. `x = x + [v]` re-renders;
   `x.append(v)` silently does not.
2. A `setTimeout` callback reads the render-time snapshot of reactive state, not
   the latest value. So every scheduled beat computes from values CAPTURED in
   its enclosing call frame and assigns absolute values. That is why the walk is
   a self-scheduling step function, and why the walk/response handshake goes
   through PENDING (module state) instead of a `has` field.
"""

impl Level.load_board -> None {
    # No model involved -- a graph read, so the page paints the real evidence
    # immediately. Guarded: a mount effect that throws blanks the page and then
    # loops on the error boundary. A demo degrades to usable, never to blank.
    try {
        result = root spawn Board();
        if len(result.reports) > 0 {
            b = result.reports[-1] as dict;
            evidence = b["evidence"] as list[dict];
            note = "Four things the AI is allowed to read. Some were confirmed true beforehand — the AI is never told which.";
        }
    } except Exception as e {
        note = "Couldn't load the evidence — press WATCH IT HAPPEN to retry.";
    }
}


impl Level.step_walk(chosen: list[str], i: int) -> None {
    if i >= len(chosen) {
        finish_walk();
        return;
    }
    walkerAt = chosen[i];
    collected = chosen[0 : i + 1];
    note = "It opens: " + (NAMES[chosen[i]] if chosen[i] in NAMES else chosen[i]) + ". Opening it is what puts it on the record.";
    # 2.4s per stop -- long enough to read the highlighted card.
    setTimeout(lambda { step_walk(chosen, i + 1); }, 2400);
}


impl Level.finish_walk -> None {
    # Hand-off between animation and network without clock arithmetic. PENDING
    # is module state, so this reads the CURRENT value rather than the snapshot
    # this closure was created with. If the model is still thinking, the beat
    # simply holds -- which is what it is there for.
    r = PENDING["data"] as dict;
    if not r {
        setTimeout(lambda { finish_walk(); }, 250);
        return;
    }

    # The record the walker actually produced wins over the route we asked for.
    collected = r["touched"] as list[str];
    cited = r["cited"] as list[str];
    verdicts = r["verdicts"] as list[dict];
    evidence = r["evidence"] as list[dict];
    action = str(r["action"]);
    explanation = str(r["explanation"]);
    rate = float(r["rate"]);
    overall = str(r["overall"]);

    phase = "oracle";
    note = "It has read everything it is going to read. Now it writes its reasons.";

    ids = r["cited"] as list[str];
    setTimeout(lambda {
        phase = "audit";
        note = "Step 2. No AI from here on — the checker just looks things up.";
        walkerAt = "decision";
        step_audit(ids, 0);
    }, 3200);
}


impl Level.step_audit(ids: list[str], i: int) -> None {
    # Constant speed, identical dwell at every stop. The AI eased and curved;
    # the checker does not. The rigidity is the argument -- do not soften it.
    if i >= len(ids) {
        auditAt = "";
        checkLine = "";
        phase = "score";
        note = "Done. Run it again and the checker gives exactly the same answer.";
        busy = False;
        return;
    }
    auditAt = ids[i];
    name = NAMES[ids[i]] if ids[i] in NAMES else ids[i];
    note = "Checking what it said about: " + name;

    # Spell out the two lookups. This IS the deterministic layer -- there is no
    # judgement in it, just set membership and a stored flag, so it should read
    # like arithmetic rather than an opinion.
    v = verdict_of(ids[i]);
    did_read = "YES" if ids[i] in collected else "NO";
    confirmed = "YES" if v == "grounded" else "NO";
    word = VERDICT_WORD[v] if v in VERDICT_WORD else v;
    if did_read == "NO" {
        checkLine = name + "  ·  did it actually read this? NO  →  " + word;
    } else {
        checkLine = name + "  ·  did it actually read this? YES  ·  was it confirmed beforehand? " + confirmed + "  →  " + word;
    }
    setTimeout(lambda { step_audit(ids, i + 1); }, 2100);
}


impl Level.run_level(chosen: list[str], inject: list[str]) -> None {
    busy = True;
    phase = "board";
    note = "Four things the AI is allowed to read. Some were confirmed true beforehand — the AI is never told which.";
    collected = [];
    cited = [];
    verdicts = [];
    walkerAt = "root";
    auditAt = "";
    overall = "";
    action = "";
    explanation = "";
    rate = 0.0;
    checkLine = "";
    PENDING["data"] = None;

    # The walk starts and the server call fires together, so real model latency
    # is spent inside the animation rather than behind a spinner.
    setTimeout(lambda {
        phase = "walk";
        note = "Watch what it actually opens. Every one it opens gets recorded automatically.";
        step_walk(chosen, 0);
    }, 1800);

    result = root spawn RouteRun(route=chosen, inject=inject);

    if len(result.reports) > 0 {
        # Park it; finish_walk() collects it once the animation has landed, so
        # the two never fight over `collected`.
        PENDING["data"] = result.reports[-1];
    } else {
        phase = "idle";
        note = "The walker didn't respond. Press START OVER and try again.";
        busy = False;
    }
}


impl Level.start_guided -> None {
    mode = "guided";
    lying = False;
    route = ["E1", "E2", "E3", "E4"];
    run_level(["E1", "E2", "E3", "E4"], []);
}


impl Level.start_free -> None {
    mode = "free";
    phase = "picking";
    busy = False;
    route = [];
    collected = [];
    cited = [];
    verdicts = [];
    walkerAt = "root";
    auditAt = "";
    overall = "";
    action = "";
    explanation = "";
    rate = 0.0;
    lying = False;
    note = "Your turn. Click the circles to choose what the AI gets to read, then press RUN IT.";
}


impl Level.toggle_node(nid: str) -> None {
    if mode != "free" or phase != "picking" or busy {
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
    names = [NAMES[r] if r in NAMES else r for r in next];
    if len(next) > 0 {
        note = "It will read: " + ", ".join(names) + ".  Press RUN IT when you're ready.";
    } else {
        note = "Nothing picked yet. Click the circles to choose what the AI gets to read.";
    }
}


impl Level.toggle_lie -> None {
    lying = not lying;
    if lying {
        note = "Lie armed. The AI will also claim it read something it never opened. Press RUN IT and watch the checker catch it.";
    } else {
        note = "Lie switched off. Press RUN IT for an honest run.";
    }
}


impl Level.commit_free -> None {
    # "E9" exists nowhere on the graph, so the walker cannot possibly have read
    # it -- which is exactly why the checker will call it out.
    run_level(route, ["E9"] if lying else []);
}


impl Level.reset -> None {
    phase = "idle";
    mode = "guided";
    busy = False;
    route = [];
    collected = [];
    cited = [];
    verdicts = [];
    walkerAt = "root";
    auditAt = "";
    overall = "";
    action = "";
    explanation = "";
    rate = 0.0;
    lying = False;
    note = "Four things the AI is allowed to read. Some were confirmed true beforehand — the AI is never told which.";
}
