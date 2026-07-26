# Provenance

**An AI agent's stated reason is not evidence that it did what it says. Provenance checks the difference — deterministically, without asking another model.**

Ask an agent why it made a decision and you get a fluent, confident paragraph.
That paragraph is generated *after* the decision, and research on
chain-of-thought faithfulness keeps finding the same thing: models frequently
cite reasons they did not actually rely on, and larger models are not reliably
better at it. In agentic settings, reasoning traces mention the cue a model
demonstrably used in fewer than one in five cases.

So the interesting question isn't "is this explanation persuasive?" It's:
**did the agent actually look at the thing it says it looked at?**

That question has a real answer. Not a judgement — a lookup.

---

## The mechanism

Every decision in Provenance carries two lists that are produced by
independent means:

| | produced by | trust |
|---|---|---|
| `cited_ids` | the model, in its structured output | **untrusted** |
| `touched_ids` | the walker's actual graph traversal | **trusted** |

The agent is a **walker** that physically moves through an evidence graph. It
does not query evidence — it *visits* it, and each `Evidence` node records the
arrival itself:

```jac
node Evidence {
    has source_id: str, content: str, verified: bool = False;

    can hand_off with EvidenceCollector entry;   # node-side ability
}

impl Evidence.hand_off {
    visitor.seen.append(self);   # self = this node, visitor = the arriving walker
}
```

That one line is the whole trick. `visit [-->[?:Evidence]]` fires it; a
filtered read like `[-->[?:Evidence]]` assigned to a variable would return the
same data and touch **nothing**. The touch record is a consequence of movement,
so it cannot be reconstructed after the fact by something guessing at what
happened.

Then a second walker — which never calls a model — compares the two lists.

```
                    ┌─────────────────┐
   evidence graph   │   Deliberator   │  walks the evidence, decides once
   ●──●──●──●  ───► │   (LLM: 1 call) │  writes cited_ids + touched_ids
                    └────────┬────────┘
                             ▼
                        ┌─────────┐
                        │ Decision│  persisted node
                        └────┬────┘
                             ▼
                    ┌─────────────────┐
                    │ ProvenanceGate  │  ZERO model calls
                    │ lookup + set ops│  grep-checkable
                    └────────┬────────┘
                             ▼
        grounded · unverified · fabricated · unsupported
```

## The four verdicts

| verdict | meaning |
|---|---|
| **grounded** | cited, actually touched, and verified before the agent ran |
| **unverified** | cited and touched, but the source was never confirmed |
| **fabricated** | cited a source its own traversal never reached |
| **unsupported** | acted while citing nothing at all |

`fabricated` is deliberately not a hard problem. It's membership in a closed,
pre-existing list — not an open-ended judgement about whether a claim is true.
That's why it's unambiguous, and why it returns the same answer every time.

---

## It runs

```
$ jac run main.jac

action      : hold
cited_ids   : ['E2', 'E4']
touched_ids : ['E1', 'E2', 'E3', 'E4']
   E2 -> unverified
   E4 -> unverified
```

### Evidence grounded in the live web

`verified` used to be something we asserted in a seed file. It isn't anymore.
A `WebEvidence` node carries a claim *and the URL it is attributed to*, and its
`verified` value is derived by fetching the page (via Firecrawl) and checking
whether the claimed text is literally present.

```
$ jac run webcase.jac

  --- web attestation (deterministic; no model involved) ---
  requested    : https://en.wikipedia.org/wiki/Business_email_compromise
  actually read: https://en.wikipedia.org/wiki/Email_spoofing   (58006 chars)

  W1  verified=True    claim present in fetched content
      "Email spoofing is the creation of email messages with a forged sender address"
  W2  verified=False   claim absent from fetched content
      "The 2019 SMTP protocol update made email spoofing technically impossible"

  --- gate (unmodified) ---
  C1 -> grounded          W1 -> grounded
  every verdict matches what the real page contains: True

  --- counterfactual: same evidence, agent cites the fabricated claim ---
  W2 -> unverified        W9 -> fabricated
```

Note `requested` versus `actually read`. The URL redirects, so the audit trail
records the page we genuinely read rather than the one we asked for. A
`grounded` verdict now terminates in a specific URL, fetched at a specific
moment, returning a specific byte count, in which the claimed text appeared.
Nothing in that chain is an opinion.

Failures fail **closed** and stay distinguishable: a missing key, a 402, a 429
or a timeout each produce `verified=False` with a note saying which — so
*"could not check"* never quietly becomes *"checked and it was fine."*

### The verdict doesn't depend on the route

If the gate graded differently depending on how the walker reached the
evidence, it would be measuring the agent's path rather than its honesty. So we
built a second agent that traverses by LLM-guided routing (`visit ... by llm`)
instead of walking everything, and ran both through the same unmodified gate:

```
$ jac run compare.jac

                      Deliberator            ExploringDeliberator
                      (unconditional visit)  (visit ... by llm)
  touched (in order)  E1,E2,E3,E4            E2,E4
  gate verdicts       E2=unverified          E2=unverified
                      E4=unverified          E4=unverified

  same set touched : False
  every verdict correct for its own route: True
```

Different order, **different set**, identical verdicts — each correct against
its own walker's touch record.

---

## Why it's hard to fake

- **The gate cannot call a model.** Not by policy — by inspection. The phrase
  that would delegate to one is absent from `gate.jac` and its annex, including
  from the comments, so `grep -c "by llm" gate.jac impl/gate.impl.jac` returning
  `0` is a real check rather than a promise. Same discipline in `web.jac`.
- **The agent cannot name its own grade.** The `Verdict` enum lives only in
  `gate.jac`, somewhere the agent's code never imports. Enforced by file layout,
  not by remembering.
- **The auditor cannot contaminate what it audits.** `Evidence.hand_off` keys on
  an `EvidenceCollector` base walker. `ProvenanceGate` doesn't inherit it, so it
  is structurally incapable of appending to a touch record — checked by the type
  system, not by discipline.
- **The model never sees `verified`.** The projection handed to the LLM
  (`EvidenceView`) carries only `source_id` and `content`. If it could see which
  evidence was pre-confirmed, it could pass the gate by citing only the safe
  items, and the gate would measure nothing.
- **No `node` ever crosses the LLM boundary.** The model fills a plain `obj`;
  our own code copies the fields onto a persisted node. A probabilistic process
  never mints graph state.

## How Jac is used

**91.1% of the tracked codebase is Jac** (1,461 of 1,603 lines — check with
`git ls-files '*.jac' | xargs wc -l`). Not as a scripting veneer: the
architecture *is* Object-Spatial Programming.

| file | role |
|---|---|
| `models.jac` | `Evidence` / `Decision` nodes, `EvidenceView` / `DecisionOutput` objs, all `sem` strings |
| `reason.jac` | the one `by llm()` function — the only place a model *decides* anything |
| `agent.jac` + `impl/` | `Deliberator` walker: `Root entry` traverses, `Root exit` decides and persists |
| `gate.jac` + `impl/` | `ProvenanceGate` walker + `Verdict` enum — zero model calls |
| `investigate.jac` + `impl/` | `ExploringDeliberator`, overriding only `gather` to route by LLM |
| `web.jac` + `impl/` | Firecrawl attestation; `WebEvidence` subclasses `Evidence` |
| `services/` | `walker:pub` endpoints — walkers as REST, called by `root spawn` |
| `components/` | the browser UI, written in Jac, compiled to React |

Jac features doing real work here: **node-side vs walker-side abilities**
(`self`/`visitor` vs `self`/`here`), **walker inheritance** (`ExploringDeliberator`
inherits `conclude` so the exit path is provably identical, not copied),
**node inheritance** (`WebEvidence(Evidence)` — the existing type filter and
`hand_off` both still apply), **`sem` strings** as the actual prompt,
**`impl` annexes** separating interface from logic, **persistence by
reachability**, and **`visit ... by llm()`** for LLM-guided traversal.

## Running it

Requires the `jac` toolchain (0.34.5+) and an `ANTHROPIC_API_KEY`.
`FIRECRAWL_API_KEY` is needed only for `webcase.jac`.

```bash
export PATH="$HOME/.local/bin:$PATH"
export ANTHROPIC_API_KEY="..."
export FIRECRAWL_API_KEY="..."

jac install
jac check .
```

```bash
jac run main.jac          # agent -> decision -> gate, in the terminal
jac run webcase.jac       # live Firecrawl attestation
jac run compare.jac       # two traversal strategies, one gate
jac start main.jac --dev --port 8712   # browser UI on :8712, API on :8713
```

Walker `report` output is echoed to stdout by the runtime; append `2>/dev/null`
for a clean read.

## Scope, honestly

This does **not** verify that reasoning is good — that's unsolved, and chasing
it leads straight back to using a model to judge a model. It verifies one
narrow, checkable thing: whether the evidence an agent claimed to rely on is
evidence it actually reached, and whether that evidence was established before
it acted. The narrowness is the point; it's what makes the answer deterministic.

Some limits, stated plainly rather than buried:

- The `verified` flag on non-web evidence is seeded rather than derived.
  `WebEvidence` is where that chain terminates in something external.
- The gate emits a verdict. Wiring that verdict to block a real payment is an
  integration, not something claimed here.
- There are exactly **two** places a model is called — `reason.jac` (the
  decision) and `investigate.jac` (LLM-guided traversal). Neither is in the
  gate, and the gate's grade never depends on which of them ran.
- `by llm()` returns `str` and is parsed into `DecisionOutput` inside
  `reason.jac`, rather than returning the `obj` directly. Structured `obj`
  returns crash byLLM's schema builder on jac 0.34.5 (`ir_info.return_type`
  arrives as a `str` where an `Info` is expected). The workaround is contained
  entirely in that one file; the call site is unchanged, and reverting it is
  four lines once the runtime is fixed.

The guardian must never be another LLM casually judging the first LLM. Models
may extract and summarise evidence. Deterministic code decides whether the
citation was real.
