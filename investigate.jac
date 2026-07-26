"""Provenance -- an alternative route to the same decision.

ExploringDeliberator exists to attack one specific claim: that the gate's
verdict is a property of the Decision, not of how the walker happened to reach
the evidence. If a different traversal strategy produced a different grade for
the same facts, the gate would be measuring the agent's route rather than its
honesty, and the whole argument would be circular.

It subclasses Deliberator rather than re-implementing it. That is deliberate:
`conclude` is INHERITED, not copied, so the exit path -- build EvidenceView
from self.seen, call the same decide(), construct a Decision with all four
fields -- is provably the same code rather than a duplicate that can drift.
EvidenceCollector is still in the chain, so Evidence.hand_off still fires and
the touch record is produced by traversal exactly as before.

Only `gather` is overridden. One ability differs; everything else is shared.

Nothing in models.jac, reason.jac, agent.jac or gate.jac is touched by this
file. It is additive.
"""

import from models { Evidence }
import from agent { Deliberator }


walker ExploringDeliberator(Deliberator) {
    override can gather with Root entry;
}
