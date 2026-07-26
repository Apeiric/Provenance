"""Implementation annex for agent.jac."""

impl Deliberator.gather {
    # `visit`, not `[-->][?:Evidence]` read into a variable. The distinction
    # is the project: a read materialises a list and touches nothing, so
    # Evidence.hand_off never fires and `self.seen` stays empty. Only actual
    # traversal produces the touch record. Swapping this line for a read
    # would still "work" -- it would just quietly make touched_ids a fiction.
    visit [-->][?:Evidence];
}


impl Deliberator.conclude {
    # Root exit: fires after every Evidence has been visited, so self.seen is
    # the complete, traversal-produced record of what was actually reached.

    # Project each touched node into the LLM-facing view. source_id and
    # content only -- `verified` is deliberately not carried across, so the
    # model cannot see which evidence was pre-confirmed and cannot pass the
    # gate by citing only the safe items.
    views = [
        EvidenceView(source_id=e.source_id, content=e.content)
        for e in self.seen
    ];

    result = decide(views);

    # The copy step: an obj the model filled becomes a node we construct.
    # cited_ids comes from the model and is untrusted. touched_ids is built
    # here, from self.seen, and never from anything the model said -- the two
    # must have independent provenance or comparing them proves nothing.
    d = Decision(
        action=result.action,
        cited_ids=result.cited_ids,
        touched_ids=[e.source_id for e in self.seen],
        explanation=result.explanation
    );

    root ++> d;
    report d;
}
