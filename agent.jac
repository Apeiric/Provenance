"""Provenance -- the acting walker.

Deliberator gathers evidence by traversing it, decides once, and persists a
Decision that carries both what it claimed and what it actually reached.

It inherits EvidenceCollector, which is what makes Evidence.hand_off fire on
arrival. Dropping that base class would not raise an error -- it would just
silently produce an empty touch record, so it is load-bearing.

Bodies live in impl/agent.impl.jac.
"""

import from models { Evidence, EvidenceView, Decision, EvidenceCollector }
import from reason { decide }


walker Deliberator(EvidenceCollector) {
    # WALKER-SIDE abilities. Here `self` is the walker and `here` is the
    # current node -- the opposite of Evidence.hand_off. The type in the
    # `with` clause is the NODE type being visited; in a node-side ability it
    # would be the WALKER type arriving.
    #
    # Verified empirically, because the ordering is the whole design: Root
    # exit fires LAST, after every Evidence has been entered and handed off,
    # not when the walker first steps off root. So `self.seen` is complete by
    # the time `conclude` runs.
    can gather with Root entry;
    can conclude with Root exit;
}
