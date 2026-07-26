"""The screen: evidence, the agent's stated reason, and the gate's verdict.

Stateful shell -- this component owns every reactive field and both async
handlers; handler bodies live in GateScreen.impl.jac. There is only one screen,
so there are no prop-drilled sections yet; adding them means passing these
fields down as typed props rather than growing this file.

The client reaches the server by spawning walkers, not by hand-written fetch:
`sv import` below generates the RPC stub, and `root spawn Prepare()` calls it.
Walker spawns take KWARGS (they map onto the walker's `has` fields), which is
the opposite of `def:pub` function RPC -- that one is positional-only.
"""

sv import from ..services.provenance { Prepare, Check }


glob NEUTRAL: dict[str, str] = {
    "border": "1px solid #d8d8d8",
    "background": "#fbfbfb",
    "color": "#333"
};

glob TONE: dict[str, dict[str, str]] = {
    "grounded": {"border": "1px solid #2e7d32", "background": "#e8f5e9", "color": "#1b5e20"},
    "unverified": {"border": "1px solid #ef6c00", "background": "#fff3e0", "color": "#e65100"},
    "fabricated": {"border": "1px solid #c62828", "background": "#ffebee", "color": "#b71c1c"},
    "unsupported": {"border": "1px solid #6a1b9a", "background": "#f3e5f5", "color": "#4a148c"}
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

    return <main style={{"maxWidth": "860px", "margin": "0 auto", "padding": "32px 24px",
                         "fontFamily": "ui-sans-serif, system-ui, sans-serif"}}>

        <header style={{"display": "flex", "justifyContent": "space-between",
                        "alignItems": "baseline", "marginBottom": "4px"}}>
            <h1 style={{"fontSize": "22px", "margin": "0"}}>Provenance</h1>
            <div style={{"fontSize": "13px", "color": "#666"}}>
                {"Grounding Rate " + str(int(rate * 100)) + "%" if checked else "Grounding Rate —"}
            </div>
        </header>
        <p style={{"color": "#666", "fontSize": "13px", "marginTop": "0", "marginBottom": "28px"}}>
            The agent's stated reason, checked against what it actually touched.
        </p>

        {if loading {
            <p style={{"color": "#888"}}>Gathering evidence and deciding…</p>
            skip;
        }}

        <h2 style={{"fontSize": "12px", "letterSpacing": "0.08em", "color": "#888",
                    "textTransform": "uppercase", "margin": "0 0 10px"}}>Evidence</h2>
        <div style={{"display": "flex", "gap": "12px", "flexWrap": "wrap", "marginBottom": "28px"}}>
            {for e in evidence {
                <div key={e["id"]} style={tone_of(e["id"] as str) |
                                          {"borderRadius": "10px", "padding": "12px 14px",
                                           "flex": "1 1 240px", "transition": "all 200ms"}}>
                    <div style={{"display": "flex", "justifyContent": "space-between",
                                 "alignItems": "center", "marginBottom": "6px"}}>
                        <strong style={{"fontSize": "13px"}}>{e["id"]}</strong>
                        <span style={{"fontSize": "11px", "opacity": "0.75"}}>
                            {verdict_of(e["id"] as str) if checked else ("verified" if e["verified"] else "unverified source")}
                        </span>
                    </div>
                    <div style={{"fontSize": "12px", "lineHeight": "1.45"}}>{e["content"]}</div>
                </div>
            }}
        </div>

        <h2 style={{"fontSize": "12px", "letterSpacing": "0.08em", "color": "#888",
                    "textTransform": "uppercase", "margin": "0 0 10px"}}>Decision</h2>
        <div style={{"border": "1px solid #e4e4e4", "borderRadius": "10px", "padding": "16px 18px"}}>
            <div style={{"display": "flex", "gap": "10px", "alignItems": "center",
                         "marginBottom": "10px"}}>
                <span style={{"fontWeight": "600", "fontSize": "14px"}}>{action.upper()}</span>
                {if checked {
                    <span style={(TONE[overall] if overall in TONE else NEUTRAL) |
                                 {"borderRadius": "999px", "padding": "2px 10px",
                                  "fontSize": "11px", "letterSpacing": "0.04em"}}>
                        {overall.upper()}
                    </span>
                }}
            </div>

            <p style={{"fontSize": "13px", "lineHeight": "1.6", "margin": "0", "color": "#222"}}>
                {#* One slot, not two: each slot compiles to its own unkeyed
                     fragment, and two of them as siblings makes React ask for
                     keys on something the compiler owns and we cannot name. *#}
                {if checked {
                    for (i, s) in enumerate(segments) {
                        <span key={str(i)}
                              style={{"textDecoration": "line-through", "color": "#b71c1c",
                                      "textDecorationThickness": "2px"} if s["struck"] else {}}>
                            {s["text"]}
                        </span>
                    }
                } else {
                    <span key="raw">{explanation}</span>
                }}
            </p>

            {if checked {
                <p style={{"fontSize": "11px", "color": "#888", "marginBottom": "0",
                           "marginTop": "12px"}}>
                    {"cited " + str(cited) + " · touched " + str(touched)}
                </p>
            }}
        </div>

        <button onClick={run_check}
                disabled={loading or checking or checked}
                style={{"marginTop": "20px", "padding": "10px 18px", "borderRadius": "8px",
                        "border": "1px solid #222", "background": "#222", "color": "#fff",
                        "fontSize": "13px",
                        "cursor": "default" if (loading or checking or checked) else "pointer",
                        "opacity": "0.45" if (loading or checking or checked) else "1"}}>
            {"Checked" if checked else ("Checking…" if checking else "Run grounding check")}
        </button>
    </main>;
}
