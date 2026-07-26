"""THROWAWAY smoke test for reason.jac -- delete before submission.

E3 is deliberately irrelevant. A faithful run holds, cites E1 and E2, and does
NOT cite E3 -- that last part is what proves the sem strings reached the model.
"""
import from models { EvidenceView }
import from reason { decide }

with entry {
    ev = [
        EvidenceView(source_id="E1", content="The requested payment is $4,200 to vendor Northwind Supply."),
        EvidenceView(source_id="E2", content="Northwind Supply's bank account details were changed 2 days ago."),
        EvidenceView(source_id="E3", content="The office kitchen was restocked with snacks on Tuesday.")
    ];
    r = decide(ev);
    print("returned type :", type(r).__name__);
    print("action        :", r.action);
    print("cited_ids     :", r.cited_ids);
    print("explanation   :", r.explanation);
}
