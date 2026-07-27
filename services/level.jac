"""Server endpoints for the playable level.

The player chooses an itinerary in the browser. This runs a REAL walker over
exactly that itinerary, so `Evidence.hand_off` still writes the touch record on
arrival. The player picks the route; the graph still writes the record. If those
two ever diverge the visualisation is lying, so `RouteRun` reports the touch
record it actually produced rather than echoing back the requested route.

Additive. models.jac, reason.jac, agent.jac and gate.jac are imported and
reused unchanged -- nothing in them is modified.
"""

import from models { Evidence, Decision }
import from agent { Deliberator }
import from gate { ProvenanceGate, Verdict }


walker RoutedDeliberator(Deliberator) {
    # Same base chain as Deliberator, so EvidenceCollector is still in it and
    # Evidence.hand_off still fires. `conclude` is INHERITED, not copied: the
    # exit path (project EvidenceView, call decide(), build the Decision) is
    # provably the same code the proven agent uses. Only `gather` differs.
    has route: list[str] = [];

    override can gather with Root entry;
}


walker:pub Board {
    # Cheap, LLM-free: seeds if needed and returns the evidence so the landing
    # page can show the real graph before anyone presses anything.
    can run with Root entry;
}


walker:pub RouteRun {
    # `route`  -- the itinerary the player walked, in order.
    # `inject` -- adversary mode: extra citations the agent never earned.
    has route: list[str] = [],
        inject: list[str] = [];

    can run with Root entry;
}


"""Seed the scenario if it isn't already on the graph. Single source of truth
for both Board and RouteRun -- the domain lives here and nowhere else."""
def seed_board() -> None;
