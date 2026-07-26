"""Server endpoints for the screen.

Two public walkers. `Prepare` seeds and runs the agent; `Check` runs the gate.
They are the only things the client touches.

Presentation logic (sentence segmentation, the grounding rate) lives HERE and
not in gate.jac. The gate decides verdicts and nothing else -- keeping the
formatting out of it is what lets that file stay short enough to read on stage
and stay free of anything a judge would have to take on trust.
"""

import from models { Evidence, Decision }
import from agent { Deliberator }
import from gate { ProvenanceGate, Verdict }


walker:pub Prepare {
    # `:pub` so the demo runs with no login. reports[0] = evidence,
    # reports[1] = the Decision the agent just wrote.
    can run with Root entry;
}


walker:pub Check {
    # Spawns the gate on the most recent Decision. No model is called
    # anywhere beneath this walker.
    can run with Root entry;
}


"""Distinctive tokens: long enough to be meaningful, numeric or proper."""
def _tokens(text: str) -> list[str] {
    out = [];
    cleaned = text.replace(",", " ").replace(".", " ").replace("$", " ");
    for tok in cleaned.split(" ") {
        t = tok.strip();
        if len(t) >= 4 and (t.isdigit() or t[0].isupper()) {
            out.append(t);
        }
    }
    return out;
}


"""Tokens that identify `target` and appear in NO grounded evidence.

Shared words are the trap here: both seeded items name the same vendor, so
matching on "Northwind" would strike sentences that are perfectly well
grounded. Subtracting every token that also appears in grounded evidence
leaves only what actually distinguishes the ungrounded claim -- in the
seeded scenario, the account number.
"""
def _markers(target: Evidence, grounded: list[Evidence]) -> list[str] {
    safe = [];
    for g in grounded {
        safe = safe + _tokens(g.content);
    }
    out = [target.source_id];
    for t in _tokens(target.content) {
        if t not in safe {
            out.append(t);
        }
    }
    return out;
}


"""Split the stated reason into sentences, flagging the ungrounded ones."""
def _segment(explanation: str, markers: list[str]) -> list[dict] {
    flattened = explanation.replace("! ", ". ").replace("? ", ". ");
    parts = flattened.split(". ");
    segs = [];
    for (i, p) in enumerate(parts) {
        text = p if i == len(parts) - 1 else p + ". ";
        struck = False;
        for m in markers {
            if m in text {
                struck = True;
            }
        }
        segs.append({"text": text, "struck": struck});
    }
    return segs;
}
