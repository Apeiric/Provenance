"""Provenance -- entry point.

The domain lives here, in the seed, and nowhere else. reason.jac and the
walkers work unchanged whatever this file puts on the graph, which is why
swapping in the trading scenario means editing only this file.
"""

import from models { Evidence, Decision }
import from agent { Deliberator }

with entry {
    # Persistence in Jac is by reachability from root, so nodes from a
    # previous run are still attached. Clear them, or every run stacks
    # another copy of the scenario onto the graph.
    for n in [root -->][?:Evidence] {
        del n;
    }
    for n in [root -->][?:Decision] {
        del n;
    }

    root ++> Evidence(
        source_id="E1",
        content="Northwind Supply has been paid 14 times over 3 years with no disputes, always to account ending 4471.",
        verified=True
    );
    root ++> Evidence(
        source_id="E2",
        content="An email from Northwind Supply requests that this $4,200 payment go to a new account ending 9086, effective immediately.",
        verified=False
    );

    result = root spawn Deliberator();
    d = result.reports[0];

    print("action      :", d.action);
    print("cited_ids   :", d.cited_ids);
    print("touched_ids :", d.touched_ids);
    print("explanation :", d.explanation);
}
