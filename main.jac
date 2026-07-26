"""Provenance -- entry point.

The domain lives here, in the seed, and nowhere else. reason.jac and the
walkers work unchanged whatever this file puts on the graph, which is why
swapping in the trading scenario means editing only this file.
"""

import from models { Evidence, Decision }
import from agent { Deliberator }
import from gate { ProvenanceGate }
import from services.provenance { Prepare, Check }
import from .components.GateScreen { GateScreen }


# Client entry. `jac start` serves this; `jac run main.jac` runs the CLI path below.
def:pub app() -> JsxElement {
    return <GateScreen />;
}

with entry:__main__ {
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
    # Additive: E3 is routine confirmation, E4 is the material anomaly. They
    # give an LLM-routed walker something real to prioritise between --
    # see compare.jac. Deliberator's own behaviour is unchanged: it still
    # queues every Evidence node unconditionally.
    root ++> Evidence(
        source_id="E3",
        content="The vendor contact phone number on file is unchanged for 3 years and matches the number on the last 14 invoices.",
        verified=True
    );
    root ++> Evidence(
        source_id="E4",
        content="The email requesting the account change was sent from a domain registered 6 days ago.",
        verified=False
    );

    result = root spawn Deliberator();
    # `reports` is untyped, so name what came back before using it as a node.
    d = result.reports[0] as Decision;

    print("action      :", d.action);
    print("cited_ids   :", d.cited_ids);
    print("touched_ids :", d.touched_ids);
    print("explanation :", d.explanation);

    # Second spawn, on the Decision the agent just wrote. No LLM below here.
    print("");
    print("--- gate ---");
    for f in (d spawn ProvenanceGate()).reports {
        print("  ", f["id"], "->", f["verdict"]);
    }
}
