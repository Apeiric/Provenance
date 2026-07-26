"""Implementation annex for models.jac."""

impl Evidence.hand_off {
    # NODE-SIDE ability. The mapping here is the one that fails silently if
    # you get it backwards, so it is worth stating flatly:
    #
    #     self    = this Evidence node        (NOT the walker)
    #     visitor = the arriving walker       (NOT the node)
    #
    # In a walker-side ability the two names would be `self` = the walker and
    # `here` = the node. Swapping them does not raise -- the ability simply
    # never does what you meant, and the touch record silently comes back
    # empty, which is the one failure this project cannot afford.
    #
    # This single line is what makes "touched" a real record: it fires because
    # a walker physically arrived, so it cannot be produced by a query, and it
    # cannot be written after the fact by anything reconstructing what it
    # thinks happened.
    visitor.seen.append(self);
}
