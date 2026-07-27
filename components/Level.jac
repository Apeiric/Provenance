"""PROVENANCE — the protocol, playable.

The pitch describes a protocol; this makes it a place you move through.

The board is the evidence graph. The player (or the Guided Run) walks a route
through it. Every arrival fires `Evidence.hand_off` server-side, so the touch
record is produced by movement — the same guarantee the CLI demo rests on, now
visible. Then the gate runs, and it cannot be talked out of its answer.

Two characters, two motion languages, and the contrast is the argument:
  agent  — curved arcs, eased, variable dwell, warm
  gate   — straight lines, constant velocity, fixed dwell, cold
One is probabilistic. One is a lookup. You feel which is which before anyone
says a word.

`main.jac` may hold exactly ONE relative component import (verified: a second
one breaks the server module with "attempted relative import with no known
parent package"), so this file is the single client entry and everything else
hangs off it.
"""

sv import from ..services.level { Board, RouteRun }


# Stage is a fixed 1000x420 SVG coordinate space; the wrapper scales it.
glob STAGE_W: int = 1000;
glob STAGE_H: int = 330;

glob NODES: list[dict] = [
    {"id": "root", "x": 70, "y": 165, "label": "root"},
    {"id": "E1", "x": 275, "y": 68, "label": "E1"},
    {"id": "E2", "x": 445, "y": 258, "label": "E2"},
    {"id": "E3", "x": 630, "y": 68, "label": "E3"},
    {"id": "E4", "x": 800, "y": 258, "label": "E4"},
    {"id": "decision", "x": 938, "y": 165, "label": "Decision"}
];

glob TONE: dict[str, dict[str, str]] = {
    "grounded": {"stroke": "rgba(63,185,80,0.85)", "fill": "rgba(63,185,80,0.16)", "text": "#56D364"},
    "unverified": {"stroke": "rgba(248,81,73,0.85)", "fill": "rgba(248,81,73,0.17)", "text": "#FF7B72"},
    "fabricated": {"stroke": "rgba(248,81,73,0.95)", "fill": "rgba(248,81,73,0.26)", "text": "#FF9492"},
    "unsupported": {"stroke": "rgba(163,113,247,0.85)", "fill": "rgba(163,113,247,0.16)", "text": "#C29BFF"}
};

glob NEUTRAL: dict[str, str] = {
    "stroke": "#2B2B33", "fill": "#131317", "text": "#8A8A94"
};

glob CSS: str = "@keyframes lv-ring{0%{stroke-width:1.5;opacity:1}50%{stroke-width:4;opacity:.72}100%{stroke-width:1.5;opacity:1}} .lv-ring{animation:lv-ring 1.15s ease-in-out infinite} @keyframes lv-draw{from{stroke-dashoffset:620}to{stroke-dashoffset:0}} .lv-drawn{stroke-dasharray:620;animation:lv-draw 700ms cubic-bezier(.3,.9,.3,1) forwards} @keyframes lv-scan{0%{transform:scaleX(.1);opacity:.35}50%{transform:scaleX(1);opacity:1}100%{transform:scaleX(.1);opacity:.35}} .lv-scan{animation:lv-scan 1.5s ease-in-out infinite} @keyframes lv-veil{from{opacity:0}to{opacity:1}} .lv-veil{animation:lv-veil 420ms ease forwards} @keyframes lv-pop{0%{opacity:0;transform:translateY(6px) scale(.94)}70%{opacity:1;transform:translateY(-2px) scale(1.02)}100%{opacity:1;transform:translateY(0) scale(1)}} @keyframes lv-score{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}} .lv-scorein{animation:lv-score 480ms cubic-bezier(.2,.8,.2,1) forwards} @keyframes lv-narr{from{opacity:.25}to{opacity:1}} .lv-narr{animation:lv-narr 500ms ease}";

glob PENDING: dict = {"data": None};

glob MONO: str = "ui-monospace, SFMono-Regular, Menlo, monospace";
glob SANS: str = "ui-sans-serif, Inter, system-ui, -apple-system, sans-serif";


def:pub Level -> JsxElement {
    has phase: str = "idle",
        mode: str = "guided",
        evidence: list[dict] = [],
        route: list[str] = [],
        walkerAt: str = "root",
        auditAt: str = "",
        collected: list[str] = [],
        touched: list[str] = [],
        cited: list[str] = [],
        verdicts: list[dict] = [],
        action: str = "",
        explanation: str = "",
        rate: float = 0.0,
        overall: str = "",
        injectText: str = "",
        note: str = "",
        busy: bool = False;

    can with entry {
        load_board();
    }

    async def load_board -> None;
    async def run_level(chosen: list[str], inject: list[str]) -> None;
    def step_walk(chosen: list[str], i: int) -> None;
    def step_audit(ids: list[str], i: int) -> None;
    def finish_walk -> None;
    def start_guided -> None;
    def start_free -> None;
    def toggle_node(nid: str) -> None;
    def commit_free -> None;
    def reset -> None;

    # ---- pure layout helpers (no state mutation) ----

    def node_at(nid: str) -> dict {
        for n in NODES {
            if n["id"] == nid {
                return n;
            }
        }
        return NODES[0];
    }

    # Quadratic arc between two nodes. Agents travel curves, never lines.
    def arc(a: str, b: str) -> str {
        p = node_at(a);
        q = node_at(b);
        mx = (p["x"] as int + (q["x"] as int)) / 2;
        my = min(p["y"] as int, q["y"] as int) - 52;
        return "M " + str(p["x"]) + "," + str(p["y"]) + " Q " + str(mx) + "," + str(my) + " " + str(q["x"]) + "," + str(q["y"]);
    }

    def verdict_of(eid: str) -> str {
        for v in verdicts {
            if v["id"] == eid {
                return v["verdict"] as str;
            }
        }
        return "";
    }

    def tone_of(eid: str) -> dict[str, str] {
        # Before the audit every node looks identical on purpose: you cannot
        # tell a sound citation from an unsound one by looking, which is the
        # position a human reviewer is actually in.
        if phase != "score" and phase != "audit" {
            return NEUTRAL;
        }
        v = verdict_of(eid);
        return TONE[v] if v in TONE else NEUTRAL;
    }

    def content_of(eid: str) -> str {
        for e in evidence {
            if e["id"] == eid {
                return e["content"] as str;
            }
        }
        return "";
    }

    def is_collected(eid: str) -> bool {
        return eid in collected;
    }

    return <main style={{"minHeight": "100vh", "background": "#08080A", "color": "#E6E6E9",
                         "fontFamily": SANS, "padding": "16px 26px", "overflow": "hidden"}}>
      <style>{CSS}</style>
      <div style={{"maxWidth": "1180px", "margin": "0 auto"}}>

        {#* ---------------- header ---------------- *#}
        <div style={{"display": "flex", "justifyContent": "space-between",
                     "alignItems": "baseline"}}>
            <div style={{"display": "flex", "gap": "14px", "alignItems": "baseline"}}>
                <span style={{"fontSize": "19px", "fontWeight": "600",
                              "letterSpacing": "-0.01em"}}>PROVENANCE</span>
                <span style={{"fontFamily": MONO, "fontSize": "10.5px", "color": "#6B6B75",
                              "letterSpacing": "0.14em", "textTransform": "uppercase"}}>
                    {"the protocol, playable"}
                </span>
            </div>
            <div style={{"fontFamily": MONO, "fontSize": "13px",
                         "fontVariantNumeric": "tabular-nums",
                         "color": "#E6E6E9" if phase == "score" else "#6B6B75"}}>
                {"Grounding Rate " + str(int(rate * 100)) + "%" if phase == "score" else "Grounding Rate —"}
            </div>
        </div>

        {#* ---------------- narration ---------------- *#}
        <div className="lv-narr" style={{"fontFamily": MONO, "fontSize": "12.5px",
                                      "color": "#8A8A94", "marginTop": "6px",
                                      "minHeight": "18px"}}>{note}</div>

        {#* the claim under the walker's feet *#}
        <div style={{"fontSize": "13px", "color": "#C9C9D1", "marginTop": "2px",
                     "minHeight": "20px", "fontFamily": SANS,
                     "opacity": "1" if (phase == "walk" and content_of(walkerAt)) else "0",
                     "transition": "opacity 300ms"}}>
            {("“" + content_of(walkerAt) + "”") if content_of(walkerAt) else ""}
        </div>

        {#* ---------------- the board ---------------- *#}
        <div style={{"position": "relative", "marginTop": "10px",
                     "border": "1px solid #17171C", "borderRadius": "14px",
                     "background": "radial-gradient(circle at 50% 40%, #0E0E12 0%, #08080A 70%)",
                     "overflow": "hidden"}}>
            <svg viewBox={"0 0 " + str(STAGE_W) + " " + str(STAGE_H)}
                 style={{"width": "100%", "display": "block"}}>

                {#* dormant edges: root -> every evidence node *#}
                {for (i, n) in enumerate(NODES) {
                    <path key={"edge" + str(i)}
                          d={arc("root", n["id"] as str)}
                          stroke="#1B1B21" strokeWidth="1.5" fill="none"
                          style={{"opacity": "0" if (n["id"] == "root" or n["id"] == "decision" or not evidence) else "1",
                                  "transition": "opacity 600ms"}} />
                }}

                {#* the walked path: only hops the walker actually made *#}
                {for (i, sid) in enumerate(collected) {
                    <path key={"walk" + str(i)}
                          className="lv-drawn"
                          d={arc(collected[i - 1] if i > 0 else "root", sid)}
                          stroke="#D9A441" strokeWidth="2.5" fill="none"
                          strokeLinecap="round" />
                }}

                {#* the closing hop: the walker writes the Decision *#}
                {if collected and (phase == "audit" or phase == "score") {
                    <path key="tail" className="lv-drawn"
                          d={arc(collected[-1], "decision")}
                          stroke="#D9A441" strokeWidth="2.5" fill="none"
                          strokeLinecap="round" strokeDasharray="5 5" />
                } else {
                    <path key="notail" d="M0,0" stroke="none" />
                }}

                {#* nodes *#}
                {for (i, n) in enumerate(NODES) {
                    <g key={"n" + str(i)}
                       style={{"opacity": "1",
                               "transition": "opacity 500ms",
                               "transitionDelay": str(90 * i) + "ms",
                               "cursor": "pointer" if (mode == "free" and phase == "walk") else "default"}}
                       onClick={lambda { toggle_node(n["id"] as str); }}>
                        <circle cx={n["x"]} cy={n["y"]}
                                r={"26" if (n["id"] == "root" or n["id"] == "decision") else "30"}
                                fill={tone_of(n["id"] as str)["fill"]}
                                stroke={tone_of(n["id"] as str)["stroke"]}
                                strokeWidth="1.5"
                                className={"lv-ring" if (walkerAt == n["id"] or auditAt == n["id"]) else ""}
                                style={{"transition": "fill 500ms, stroke 500ms"}} />
                        <text x={n["x"]} y={(n["y"] as int) + 5} textAnchor="middle"
                              style={{"fontFamily": MONO, "fontSize": "12px", "fontWeight": "600",
                                      "fill": tone_of(n["id"] as str)["text"],
                                      "pointerEvents": "none"}}>
                            {n["label"]}
                        </text>
                        <text x={n["x"]} y={(n["y"] as int) + 48} textAnchor="middle"
                              style={{"fontFamily": MONO, "fontSize": "9.5px",
                                      "fill": "#56D364" if is_collected(n["id"] as str) else "#4A4A54",
                                      "letterSpacing": "0.1em", "pointerEvents": "none"}}>
                            {"◆ TOUCHED" if is_collected(n["id"] as str) else ""}
                        </text>
                    </g>
                }}

                {#* the agent — curved travel, eased *#}
                <circle className="agent" r="11" fill="#F0B429"
                        cx={node_at(walkerAt)["x"]} cy={node_at(walkerAt)["y"]}
                        style={{"opacity": "0" if (phase == "idle" or phase == "board" or phase == "audit" or phase == "score") else "1",
                                "transition": "cx 780ms cubic-bezier(.34,1.4,.5,1), cy 780ms cubic-bezier(.34,1.4,.5,1), opacity 300ms"}} />

                {#* the auditor — straight, constant velocity, no easing *#}
                <rect className="auditor" width="18" height="18"
                      x={(node_at(auditAt)["x"] as int) - 9} y={(node_at(auditAt)["y"] as int) - 9}
                      fill="none" stroke="#7FD1FF" strokeWidth="2"
                      style={{"opacity": "1" if phase == "audit" else "0",
                              "transition": "x 420ms linear, y 420ms linear, opacity 200ms"}} />
            </svg>

            {#* the membrane / oracle beat — covers real LLM latency *#}
            {if phase == "oracle" {
                <div className="lv-veil" style={{"position": "absolute", "top": "0", "left": "0",
                             "right": "0", "bottom": "0", "display": "flex",
                             "alignItems": "center", "justifyContent": "center",
                             "flexDirection": "column", "gap": "10px",
                             "background": "rgba(8,8,10,0.82)"}}>
                    <div style={{"fontFamily": MONO, "fontSize": "11px", "letterSpacing": "0.18em",
                                 "color": "#F0B429"}}>CROSSING THE MODEL BOUNDARY</div>
                    <div style={{"fontFamily": MONO, "fontSize": "12px", "color": "#8A8A94",
                                 "maxWidth": "520px", "textAlign": "center", "lineHeight": "1.6"}}>
                        {"the verified flags stay behind — the model receives claims only"}
                    </div>
                    <div className="lv-scan" style={{"width": "220px", "height": "2px",
                                                  "background": "#F0B429", "marginTop": "6px"}} />
                </div>
            } else {
                <span key="noveil" />
            }}
        </div>

        {#* ---------------- ledgers ---------------- *#}
        <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "12px",
                     "marginTop": "12px"}}>
            <div style={{"border": "1px solid #17171C", "borderRadius": "10px",
                         "padding": "10px 13px", "background": "#0C0C10"}}>
                <div style={{"fontFamily": MONO, "fontSize": "9.5px", "letterSpacing": "0.16em",
                             "color": "#6B6B75", "textTransform": "uppercase"}}>
                    touched · written by movement
                </div>
                <div style={{"fontFamily": MONO, "fontSize": "14px", "color": "#56D364",
                             "marginTop": "5px", "minHeight": "19px"}}>
                    {",".join(collected) if collected else "—"}
                </div>
            </div>
            <div style={{"border": "1px solid #17171C", "borderRadius": "10px",
                         "padding": "10px 13px", "background": "#0C0C10"}}>
                <div style={{"fontFamily": MONO, "fontSize": "9.5px", "letterSpacing": "0.16em",
                             "color": "#6B6B75", "textTransform": "uppercase"}}>
                    cited · asserted by the model
                </div>
                <div style={{"fontFamily": MONO, "fontSize": "14px", "color": "#F0B429",
                             "marginTop": "5px", "minHeight": "19px"}}>
                    {",".join(cited) if cited else "—"}
                </div>
            </div>
        </div>

        {#* ---------------- score / controls ---------------- *#}
        {if phase == "score" {
            <div className="lv-scorein" style={{"marginTop": "12px", "border": "1px solid #17171C",
                         "borderRadius": "12px", "padding": "14px 16px", "background": "#0C0C10"}}>
                <div style={{"display": "flex", "alignItems": "center", "gap": "11px",
                             "marginBottom": "9px"}}>
                    <span style={{"fontFamily": MONO, "fontSize": "15px", "fontWeight": "600"}}>
                        {action.upper()}
                    </span>
                    <span style={{"fontFamily": MONO, "fontSize": "10.5px", "padding": "3px 12px",
                                  "borderRadius": "999px", "letterSpacing": "0.1em",
                                  "color": (TONE[overall]["text"] if overall in TONE else "#8A8A94"),
                                  "border": "1px solid " + (TONE[overall]["stroke"] if overall in TONE else "#2B2B33"),
                                  "background": (TONE[overall]["fill"] if overall in TONE else "#131317")}}>
                        {overall.upper()}
                    </span>
                </div>
                <p style={{"fontSize": "13.5px", "lineHeight": "1.6", "margin": "0",
                           "color": "#C9C9D1"}}>{explanation}</p>
                <div style={{"display": "flex", "gap": "8px", "flexWrap": "wrap",
                             "marginTop": "11px"}}>
                    {for (i, v) in enumerate(verdicts) {
                        <span key={"v" + str(i)}
                              style={{"fontFamily": MONO, "fontSize": "10.5px", "padding": "4px 10px",
                                      "borderRadius": "6px", "letterSpacing": "0.06em",
                                      "color": TONE[v["verdict"] as str]["text"] if (v["verdict"] as str) in TONE else "#8A8A94",
                                      "border": "1px solid " + (TONE[v["verdict"] as str]["stroke"] if (v["verdict"] as str) in TONE else "#2B2B33"),
                                      "background": TONE[v["verdict"] as str]["fill"] if (v["verdict"] as str) in TONE else "#131317",
                                      "opacity": "0", "animation": "lv-pop 420ms ease forwards",
                                      "animationDelay": str(140 * i) + "ms"}}>
                            {str(v["id"]) + " · " + str(v["verdict"]).upper()}
                        </span>
                    }}
                </div>
            </div>
        } else {
            <span key="noscore" />
        }}

        <div style={{"display": "flex", "gap": "9px", "alignItems": "center",
                     "marginTop": "13px", "flexWrap": "wrap"}}>
            <button onClick={start_guided} disabled={busy}
                    style={{"fontFamily": MONO, "fontSize": "12px", "padding": "10px 18px",
                            "borderRadius": "8px", "border": "1px solid #E6E6E9",
                            "background": "#E6E6E9" if not busy else "#16161B",
                            "color": "#08080A" if not busy else "#5A5A64",
                            "cursor": "pointer" if not busy else "default"}}>
                {"GUIDED RUN"}
            </button>
            <button onClick={start_free} disabled={busy}
                    style={{"fontFamily": MONO, "fontSize": "12px", "padding": "10px 18px",
                            "borderRadius": "8px", "border": "1px solid #2B2B33",
                            "background": "#101014", "color": "#C9C9D1",
                            "cursor": "pointer" if not busy else "default"}}>
                {"FREE PLAY"}
            </button>
            {if mode == "free" and phase == "walk" {
                <button key="commit" onClick={commit_free} disabled={busy}
                        style={{"fontFamily": MONO, "fontSize": "12px", "padding": "10px 18px",
                                "borderRadius": "8px", "border": "1px solid #D9A441",
                                "background": "rgba(217,164,65,0.14)", "color": "#F0B429",
                                "cursor": "pointer"}}>
                    {"COMMIT ROUTE (" + str(len(route)) + ")"}
                </button>
            } else {
                <span key="nocommit" />
            }}
            <button onClick={reset} disabled={busy}
                    style={{"fontFamily": MONO, "fontSize": "12px", "padding": "10px 14px",
                            "borderRadius": "8px", "border": "1px solid #2B2B33",
                            "background": "transparent", "color": "#6B6B75",
                            "cursor": "pointer"}}>
                {"RESET"}
            </button>
        </div>
      </div>
    </main>;
}
