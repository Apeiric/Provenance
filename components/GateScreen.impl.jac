"""Handler bodies for GateScreen.

Reactive `has` fields are assigned directly -- no setter call. They must be
REBOUND, never mutated in place: `x = x + [item]` re-renders, `x.append(item)`
silently does not.
"""

impl GateScreen.load {
    # Walker spawn, not fetch. Inside an async context the spawn awaits
    # implicitly. reports[0] is the evidence, reports[1] the decision.
    result = root spawn Prepare();
    if result.reports {
        # reports[-1], never [0]: a walker spawned inside Prepare leaks its own
        # reports into this list ahead of ours. Ours is always emitted last.
        d = result.reports[-1];
        evidence = d["evidence"];
        action = d["action"];
        explanation = d["explanation"];
        cited = d["cited"];
        touched = d["touched"];
    }
    loading = False;
}


impl GateScreen.run_check {
    checking = True;
    result = root spawn Check();
    if result.reports {
        c = result.reports[-1];   # see note in load(): the gate's reports precede ours
        verdicts = c["verdicts"];
        segments = c["segments"];
        rate = c["rate"];
        overall = c["overall"];
        checked = True;
    }
    checking = False;
}


impl GateScreen.verdict_of(eid: str) -> str {
    for v in verdicts {
        if v["id"] == eid {
            return v["verdict"] as str;
        }
    }
    return "";
}


impl GateScreen.tone_of(eid: str) -> dict[str, str] {
    # Before the check runs every node looks the same on purpose: the point of
    # the demo is that you cannot tell which citation is sound by looking at
    # it, which is exactly the position a human reviewer is in.
    if not checked {
        return NEUTRAL;
    }
    v = verdict_of(eid);
    return TONE[v] if v in TONE else NEUTRAL;
}
