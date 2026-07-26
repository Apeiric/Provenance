"""The Split-Truth Interface.

Two truths on one screen, in two deliberately incompatible visual languages:
the left column is the agent's belief, set in sans-serif prose so it reads like
a person talking; the right column is the record, set in monospace so it reads
like a ledger. They are never merged into a single verdict line, because the
gap between them IS the product.

Each evidence item is one CSS grid row spanning both columns, so a claim and
its ground truth are physically at the same height and cannot drift apart.

Layout only. Every value rendered here already existed in component state --
`load`, `run_check`, `verdict_of` and `tone_of` in GateScreen.impl.jac are
untouched, as are the services, the RPC wiring, and the strikethrough matching.

The client reaches the server by spawning walkers, not by hand-written fetch:
`sv import` below generates the RPC stub, and `root spawn Prepare()` calls it.
Walker spawns take KWARGS (they map onto the walker's `has` fields), which is
the opposite of `def:pub` function RPC -- that one is positional-only.
"""

sv import from ..services.provenance { Prepare, Check }


# Pre-check, and for anything the agent never cited. Every row wears this
# until the gate answers -- a judge must not be able to tell which citation is
# sound by looking at it, which is exactly the position a human reviewer is in.
glob NEUTRAL: dict[str, str] = {
    "border": "1px solid #232329",
    "background": "#131317",
    "color": "#8A8A94",
    "boxShadow": "0 0 0 rgba(0,0,0,0)"
};

# Matched reads green on both sides, mismatched reads RED on both sides. The
# unverified/fabricated distinction survives in the verdict word rather than in
# the hue: at projector distance a judge should register pass/fail before they
# register which kind of fail. Alphas are deliberately heavy -- 10% tint on a
# near-black canvas is invisible past the second row of seats.
glob TONE: dict[str, dict[str, str]] = {
    "grounded": {
        "border": "1px solid rgba(63,185,80,0.55)",
        "background": "rgba(63,185,80,0.16)",
        "color": "#56D364",
        "boxShadow": "0 0 26px rgba(63,185,80,0.13)"
    },
    "unverified": {
        "border": "1px solid rgba(248,81,73,0.58)",
        "background": "rgba(248,81,73,0.17)",
        "color": "#FF7B72",
        "boxShadow": "0 0 30px rgba(248,81,73,0.20)"
    },
    "fabricated": {
        "border": "1px solid rgba(248,81,73,0.78)",
        "background": "rgba(248,81,73,0.24)",
        "color": "#FF9492",
        "boxShadow": "0 0 34px rgba(248,81,73,0.28)"
    },
    "unsupported": {
        "border": "1px solid rgba(163,113,247,0.55)",
        "background": "rgba(163,113,247,0.16)",
        "color": "#C29BFF",
        "boxShadow": "0 0 26px rgba(163,113,247,0.14)"
    }
};

glob SANS: str = "ui-sans-serif, Inter, system-ui, -apple-system, sans-serif";
glob MONO: str = "ui-monospace, SFMono-Regular, Menlo, monospace";

glob LABEL: dict[str, str] = {
    "fontFamily": "ui-monospace, SFMono-Regular, Menlo, monospace",
    "fontSize": "10.5px",
    "letterSpacing": "0.14em",
    "textTransform": "uppercase",
    "color": "#8A8A94"
};

glob CELL: dict[str, str] = {
    "borderRadius": "10px",
    "padding": "13px 16px",
    "transitionProperty": "background, border-color, color, box-shadow",
    "transitionDuration": "420ms",
    "transitionTimingFunction": "cubic-bezier(0.2, 0.8, 0.2, 1)"
};


def:pub GateScreen -> JsxElement {
    has evidence: list[dict] = [],
        action: str = "",
        explanation: str = "",
        cited: list[str] = [],
        touched: list[str] = [],
        verdicts: list[dict] = [],
        segments: list[dict] = [],
        rate: float = 0.0,
        overall: str = "",
        loading: bool = True,
        checking: bool = False,
        checked: bool = False;

    can with entry {
        load();
    }

    async def load -> None;
    async def run_check -> None;
    def verdict_of(eid: str) -> str;
    def tone_of(eid: str) -> dict[str, str];

    # Inline helpers -- bodies live here so GateScreen.impl.jac stays untouched.

    def note_for(eid: str) -> str {
        if not checked {
            return "awaiting check";
        }
        v = verdict_of(eid);
        if v == "grounded" {
            return "confirmed before the agent ran";
        }
        if v == "unverified" {
            return "nothing on record confirms this";
        }
        if v == "fabricated" {
            return "cited, but never reached";
        }
        return "the agent never relied on this";
    }

    def delay_for(i: int, eid: str) -> str {
        # Green resolves first; a failing row lands last and alone. The
        # ordering is the whole beat -- relief, then the drop.
        v = verdict_of(eid);
        extra = 460 if (v == "unverified" or v == "fabricated") else 0;
        return str(150 * i + extra) + "ms";
    }

    return <main style={{"minHeight": "100vh", "background": "#0B0B0D", "color": "#E6E6E9",
                         "fontFamily": SANS, "padding": "28px 28px"}}>
      <div style={{"maxWidth": "1180px", "margin": "0 auto"}}>

        <header style={{"display": "flex", "justifyContent": "space-between",
                        "alignItems": "baseline", "marginBottom": "6px"}}>
            <h1 style={{"fontSize": "20px", "margin": "0", "letterSpacing": "-0.01em",
                        "fontWeight": "600"}}>Provenance</h1>
            <div style={{"fontFamily": MONO, "fontSize": "13px",
                         "fontVariantNumeric": "tabular-nums",
                         "color": "#E6E6E9" if checked else "#8A8A94"}}>
                {"Grounding Rate " + str(int(rate * 100)) + "%" if checked else "Grounding Rate —"}
            </div>
        </header>
        <p style={{"color": "#8A8A94", "fontSize": "13px", "marginTop": "0",
                   "marginBottom": "22px"}}>
            The agent's stated reason, checked against what it actually touched.
        </p>

        {if loading {
            <p style={{"color": "#8A8A94", "fontFamily": MONO, "fontSize": "13px"}}>
                Gathering evidence and deciding…
            </p>
        } else {
            <span key="ready" />
        }}

        {#* Column headers. The two labels are the thesis in six words. *#}
        <div style={{"display": "grid", "gridTemplateColumns": "1fr 64px 1fr",
                     "marginBottom": "10px"}}>
            <div style={LABEL | {"paddingLeft": "2px"}}>What the agent believed</div>
            <div />
            <div style={LABEL | {"paddingLeft": "2px"}}>What's actually true</div>
        </div>

        {#* Top band: the confident paragraph, opposite the record it rests on. *#}
        <div style={{"display": "grid", "gridTemplateColumns": "1fr 64px 1fr",
                     "alignItems": "stretch", "marginBottom": "14px"}}>
            <div style={NEUTRAL | CELL | {"background": "#101014"}}>
                <p style={{"fontSize": "15px", "lineHeight": "1.65", "margin": "0",
                           "color": "#E6E6E9"}}>
                    {if checked {
                        for (i, s) in enumerate(segments) {
                            <span key={str(i)}
                                  style={{"textDecoration": "line-through",
                                          "textDecorationColor": "#F85149",
                                          "textDecorationThickness": "2px",
                                          "color": "#8A8A94"} if s["struck"] else {}}>
                                {s["text"]}
                            </span>
                        }
                    } else {
                        <span key="raw">{explanation}</span>
                    }}
                </p>
                {if checked {
                    <p style={{"fontFamily": MONO, "fontSize": "10.5px", "color": "#6B6B75",
                               "marginBottom": "0", "marginTop": "12px"}}>
                        {"cited " + str(cited) + " · touched " + str(touched)}
                    </p>
                } else {
                    <span key="nofoot" />
                }}
            </div>
            <div />
            <div style={NEUTRAL | CELL | {"background": "#101014", "fontFamily": MONO}}>
                <div style={LABEL}>Source of record</div>
                <div style={{"fontSize": "12.5px", "lineHeight": "1.6", "marginTop": "8px",
                             "color": "#8A8A94"}}>
                    {str(len(evidence)) + " items, each established before the agent ran."}
                </div>
                <div style={{"fontSize": "12.5px", "lineHeight": "1.6", "marginTop": "6px",
                             "color": "#8A8A94"}}>
                    The agent never saw which of them were confirmed.
                </div>
            </div>
        </div>

        {#* One grid row per evidence item: claim and ground truth locked to the
            same height, so the pairing cannot be misread. *#}
        {for (i, e) in enumerate(evidence) {
            <div key={e["id"]}
                 style={{"display": "grid", "gridTemplateColumns": "1fr 64px 1fr",
                         "alignItems": "stretch", "marginBottom": "10px"}}>

                <div style={tone_of(e["id"] as str) | CELL |
                            {"transitionDelay": delay_for(i, e["id"] as str)}}>
                    <div style={{"display": "flex", "justifyContent": "space-between",
                                 "alignItems": "baseline", "marginBottom": "7px"}}>
                        <strong style={{"fontFamily": MONO, "fontSize": "12px",
                                        "letterSpacing": "0.06em"}}>{e["id"]}</strong>
                        <span style={{"fontFamily": MONO, "fontSize": "10.5px",
                                      "opacity": "0.8"}}>
                            {"cited · relied upon" if e["id"] in cited else "not cited"}
                        </span>
                    </div>
                    <div style={{"fontSize": "13.5px", "lineHeight": "1.55",
                                 "color": "#E6E6E9"}}>{e["content"]}</div>
                </div>

                {#* The connector draws across on the row's own delay. *#}
                <div style={{"display": "flex", "alignItems": "center",
                             "justifyContent": "center", "position": "relative"}}>
                    <div style={{"position": "absolute", "height": "1px", "width": "34px",
                                 "background": "#232329"}} />
                    <div style={{"height": "3px", "borderRadius": "3px",
                                 "background": tone_of(e["id"] as str)["color"],
                                 "width": "100%" if checked else "0%",
                                 "opacity": "1" if checked else "0",
                                 "transition": "width 420ms cubic-bezier(0.2,0.8,0.2,1), opacity 420ms",
                                 "transitionDelay": delay_for(i, e["id"] as str)}} />
                </div>

                <div style={tone_of(e["id"] as str) | CELL |
                            {"fontFamily": MONO,
                             "transitionDelay": delay_for(i, e["id"] as str)}}>
                    <div style={{"display": "flex", "justifyContent": "space-between",
                                 "alignItems": "baseline", "marginBottom": "7px"}}>
                        <strong style={{"fontSize": "12px",
                                        "letterSpacing": "0.06em"}}>{e["id"]}</strong>
                        <span style={{"fontSize": "10.5px", "letterSpacing": "0.1em",
                                      "textTransform": "uppercase", "opacity": "0.9"}}>
                            {verdict_of(e["id"] as str) if checked else "—"}
                        </span>
                    </div>
                    <div style={{"fontSize": "12.5px", "lineHeight": "1.55"}}>
                        {note_for(e["id"] as str)}
                    </div>
                </div>
            </div>
        }}

        <div style={{"display": "flex", "justifyContent": "space-between",
                     "alignItems": "center", "marginTop": "26px",
                     "paddingTop": "20px", "borderTop": "1px solid #232329"}}>
            <div style={{"display": "flex", "gap": "12px", "alignItems": "center"}}>
                <span style={{"fontFamily": MONO, "fontSize": "15px", "fontWeight": "600",
                              "letterSpacing": "0.04em"}}>{action.upper()}</span>
                {if checked {
                    <span style={(TONE[overall] if overall in TONE else NEUTRAL) |
                                 {"fontFamily": MONO, "borderRadius": "999px",
                                  "padding": "3px 12px", "fontSize": "10.5px",
                                  "letterSpacing": "0.1em"}}>
                        {overall.upper()}
                    </span>
                } else {
                    <span key="nobadge" />
                }}
            </div>

            <button onClick={run_check}
                    disabled={loading or checking or checked}
                    style={{"padding": "11px 20px", "borderRadius": "8px",
                            "fontFamily": MONO, "fontSize": "12px",
                            "letterSpacing": "0.04em",
                            "border": "1px solid #2E2E36" if (loading or checking or checked) else "1px solid #E6E6E9",
                            "background": "#16161B" if (loading or checking or checked) else "#E6E6E9",
                            "color": "#6B6B75" if (loading or checking or checked) else "#0B0B0D",
                            "cursor": "default" if (loading or checking or checked) else "pointer"}}>
                {"Checked" if checked else ("Checking…" if checking else "Run grounding check")}
            </button>
        </div>
      </div>
    </main>;
}
