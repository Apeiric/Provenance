"""Implementation annex for investigate.jac."""

impl ExploringDeliberator.gather {
    # The single line that differs from Deliberator.
    #
    # Deliberator queues every Evidence node unconditionally. This asks the
    # model which ones are worth walking into, and in what order.
    #
    # Verified behaviour on jac 0.34.5, not assumed: this does NOT merely
    # reorder. The model SELECTS a subset -- in probing, it visited only the
    # candidate it judged urgent and skipped the routine ones entirely. So
    # this walker can legitimately end up with a smaller `seen` list than
    # Deliberator, which means a smaller touched_ids, which means the gate
    # may reach a different verdict from the same evidence. That is the
    # point: the verdict follows what was actually touched, whatever route
    # produced it.
    #
    # Also verified: routing crashes with "NodeAnchor is not a valid
    # reference" if nodes were deleted earlier in the same run without a
    # commit() -- byLLM enumerates the stale anchors as candidates. Any seed
    # that clears before seeding must commit() before this walker runs.
    visit [-->][?:Evidence] by llm(
        intent="Investigate the evidence most likely to change the decision -- anything anomalous, time-pressured, or inconsistent with the established pattern. Routine background that only confirms what is already known is lower priority."
    );
}
