"""Provenance -- the data vocabulary.

Declarations only. No walkers, no `by llm()`, no method bodies.

There are two tiers of type in this file, and the split between them is the
whole argument of the project:

  LLM boundary types (obj)   EvidenceView, DecisionOutput.
                             Plain values. Their `sem` strings ARE the prompt
                             text the model sees at runtime.

  Graph record types (node)  Evidence, Decision.
                             Persist by reachability from root. The model
                             never touches one, in either direction.

No `node` is ever an argument to, or a return from, a `by llm()` function.
A node mints a graph anchor, and anything reachable from root is durable --
so letting a probabilistic process mint nodes writes half-formed records into
persistent state. The model fills an `obj`; our own code copies those fields
onto a `node` it constructs itself. That copy step is where untrusted becomes
recorded, and it is deliberately ours.
"""

# ===========================================================================
# Graph record types -- never cross the LLM boundary
# ===========================================================================

walker EvidenceCollector {
    # A capability, not an agent. Anything that inherits this is declaring
    # "I collect evidence by traversing it", and Evidence.hand_off below keys
    # on exactly that.
    #
    # It lives here, in models.jac, rather than in agent.jac for a hard
    # reason: `impl` cannot cross module boundaries (E2009), so Evidence's
    # ability must be declared in this file -- and if it named `Deliberator`
    # directly, models.jac would have to import agent.jac while agent.jac
    # imports models.jac. That circular import fails at runtime, verified.
    # Keying on a base declared here breaks the cycle.
    #
    # The payoff is bigger than the workaround: the gate walker does NOT
    # inherit this, so it is structurally incapable of firing hand_off and
    # polluting the touch record it exists to audit. That is enforced by the
    # type system rather than by remembering not to.
    has seen: list[Evidence] = [];
}


node Evidence {
    # `verified` is the only defaulted field, so it goes last (non-defaulted
    # `has` fields must precede defaulted ones). Defaulting to False is the
    # safe direction: unmarked evidence is untrusted, never trusted.
    has source_id: str,
        content: str,
        verified: bool = False;

    # NODE-SIDE ability: fires when an EvidenceCollector walker arrives here.
    # Inside its body (see impl/models.impl.jac) `self` is THIS Evidence node
    # and `visitor` is the arriving walker -- the mirror image of a
    # walker-side ability, where `self` is the walker and `here` is the node.
    # Body lives in the annex; the declaration must live here.
    can hand_off with EvidenceCollector entry;
}


node Decision {
    # Every field is required -- deliberately, and against the sketch in the
    # brief, which defaulted them. A Decision that lost its provenance is
    # exactly the artifact this project exists to prevent, and a defaulted
    # `cited_ids: list[str] = []` would let a half-built Decision persist and
    # then grade as "unsupported" for a reason that was never true. Requiring
    # all four means an incomplete Decision cannot be constructed at all.
    #
    # cited_ids  vs  touched_ids is the core of the system:
    #   cited_ids   comes from the model. Untrusted.
    #   touched_ids comes from traversal. Trusted.
    # Both are written at the same moment, by the same statement, because the
    # gate runs as a separate spawn and cannot see the agent walker's memory.
    has action: str,
        cited_ids: list[str],
        touched_ids: list[str],
        explanation: str;
}


# ===========================================================================
# LLM boundary types -- plain obj, `sem` strings are live prompt text
# ===========================================================================

obj EvidenceView {
    # A projection of an Evidence node, and the only shape evidence takes when
    # it reaches the model.
    #
    # `verified` is intentionally ABSENT. If the model can see which evidence
    # was pre-confirmed, two things break at once: it can pass the gate
    # trivially by citing only the verified items, and the gate stops
    # measuring anything. It would be optimising for what looks grounded
    # rather than for what is -- the same failure as fine-tuning on gate
    # verdicts. The verified flag is the ground-truth channel; ground truth
    # does not get shown to the party being checked.
    #
    # Both fields are required. A view is always copied from a real node, so
    # there is no default that could silently stand in for a missing source.
    has source_id: str,
        content: str;
}


obj DecisionOutput {
    # The `by llm()` return type. byLLM enforces this as the output schema and
    # requires every field to be filled, so nothing here is defaulted.
    has action: str,
        cited_ids: list[str],
        explanation: str;
}


# ===========================================================================
# Semantic strings
#
# Tier 1 (LIVE): EvidenceView and DecisionOutput enter the prompt. These
# strings are the specification the model is actually working from -- edit
# them as prompt text, not as comments.
#
# Tier 2 (DORMANT): Evidence and Decision never reach a model under the
# current design, so their `sem` strings do not run today. They are kept
# because they become live the moment anything uses `visit [-->] by llm()`,
# where candidate and field descriptions are sourced from semstrings -- and
# until then they document the trust boundary in the one place that cannot
# drift away from the fields it describes.
# ===========================================================================

# --- Tier 1: live prompt text ---------------------------------------------

sem EvidenceView = "A single piece of evidence available for this decision. Treat it as the only information you have about this source.";
sem EvidenceView.source_id = "Stable identifier for this evidence. If you rely on this evidence, cite this exact string.";
sem EvidenceView.content = "The factual claim carried by this evidence, verbatim.";

sem DecisionOutput = "A decision, together with an honest record of which evidence it was actually based on.";
sem DecisionOutput.action = "The decision reached: exactly one of 'approve' or 'hold', lowercase, nothing else.";
sem DecisionOutput.cited_ids = "The source_id of every piece of evidence you actually used to reach this decision. List only evidence that genuinely influenced the outcome: do not list evidence you read but ignored, and do not list an id that was not provided to you. If no evidence influenced the decision, return an empty list -- that is a valid and honest answer.";
sem DecisionOutput.explanation = "Why this action was chosen, referring only to evidence listed in cited_ids.";

# --- Tier 2: dormant, documents the trust boundary -------------------------

sem Evidence = "A piece of evidence stored in the graph. The unit the agent traverses and the unit the gate checks against.";
sem Evidence.source_id = "Stable identifier for this evidence, and the value an agent cites.";
sem Evidence.content = "The factual claim carried by this evidence.";
sem Evidence.verified = "True only if this evidence was confirmed against a trusted source before the agent ran. Never shown to the agent and never writable by it.";

sem Decision = "A decision as it was actually made: the action taken, what the agent claimed it relied on, and what it actually reached.";
sem Decision.action = "The action the agent decided on.";
sem Decision.cited_ids = "What the agent claimed it used. Authored by the model, therefore untrusted.";
sem Decision.touched_ids = "What the agent actually visited, recorded by traversal rather than asserted afterwards. Trusted.";
sem Decision.explanation = "The agent's stated reason, kept verbatim so a stated reason can be compared against the record.";
