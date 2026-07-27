"""PROVENANCE — watch an AI show its work, then check it.

Design rule for this file: a stranger with no context should understand what
they are looking at within fifteen seconds, without anyone narrating. That
means plain words, human names instead of codes, every claim readable from the
start, and pacing slow enough to actually read.

The board is the evidence graph. A route is walked through it; every arrival is
recorded server-side by `Evidence.hand_off`, so the record of what was read is
produced by movement rather than claimed afterwards. Then the checker compares
what the AI SAID it used against what it ACTUALLY read.

Motion carries the argument: the AI moves in curves with easing, the checker
moves in straight lines at constant speed. One is a guess, one is a lookup.

`main.jac` holds exactly ONE relative component import (a second breaks the
server module), so this is the single client entry.
"""

sv import from ..services.level { Board, RouteRun }


glob STAGE_W: int = 1000;
glob STAGE_H: int = 250;

glob NODES: list[dict] = [
    {"id": "root", "x": 62, "y": 125, "label": "START"},
    {"id": "E1", "x": 268, "y": 58, "label": "E1"},
    {"id": "E2", "x": 452, "y": 196, "label": "E2"},
    {"id": "E3", "x": 636, "y": 58, "label": "E3"},
    {"id": "E4", "x": 820, "y": 196, "label": "E4"},
    {"id": "decision", "x": 946, "y": 125, "label": "DECIDE"}
];

# Human names. Nobody can reason about "E2".
glob NAMES: dict[str, str] = {
    "E1": "Payment history",
    "E2": "Request to change account",
    "E3": "Vendor's phone number",
    "E4": "Age of sender's domain"
};

glob VERDICT_WORD: dict[str, str] = {
    "grounded": "CHECKED OUT",
    "unverified": "NOT CONFIRMED",
    "fabricated": "MADE UP",
    "unsupported": "NOTHING CITED"
};

glob VERDICT_PLAIN: dict[str, str] = {
    "grounded": "read it, and it was confirmed true beforehand",
    "unverified": "read it — but nobody ever confirmed it",
    "fabricated": "never opened this. It referred to something it never read",
    "unsupported": "decided without pointing to anything"
};

glob TONE: dict[str, dict[str, str]] = {
    "grounded": {"stroke": "rgba(63,185,80,0.9)", "fill": "rgba(63,185,80,0.15)", "text": "#56D364"},
    "unverified": {"stroke": "rgba(248,81,73,0.9)", "fill": "rgba(248,81,73,0.15)", "text": "#FF7B72"},
    "fabricated": {"stroke": "rgba(248,81,73,1)", "fill": "rgba(248,81,73,0.26)", "text": "#FF9492"},
    "unsupported": {"stroke": "rgba(163,113,247,0.9)", "fill": "rgba(163,113,247,0.15)", "text": "#C29BFF"}
};

glob NEUTRAL: dict[str, str] = {
    "stroke": "#2B2B33", "fill": "#131317", "text": "#8A8A94"
};

glob PENDING: dict = {"data": None};

glob CSS: str = "@keyframes lv-ring{0%{stroke-width:1.5;opacity:1}50%{stroke-width:5;opacity:.7}100%{stroke-width:1.5;opacity:1}} .lv-ring{animation:lv-ring 1.6s ease-in-out infinite} @keyframes lv-draw{from{stroke-dashoffset:700}to{stroke-dashoffset:0}} .lv-drawn{stroke-dasharray:700;animation:lv-draw 1400ms cubic-bezier(.4,0,.2,1) forwards} @keyframes lv-scan{0%{transform:scaleX(.1);opacity:.3}50%{transform:scaleX(1);opacity:1}100%{transform:scaleX(.1);opacity:.3}} .lv-scan{animation:lv-scan 2s ease-in-out infinite} @keyframes lv-fade{from{opacity:0}to{opacity:1}} .lv-fade{animation:lv-fade 600ms ease forwards} @keyframes lv-pop{0%{opacity:0;transform:translateY(8px)}100%{opacity:1;transform:translateY(0)}} .lv-pop{opacity:0;animation:lv-pop 500ms ease forwards}";

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
        cited: list[str] = [],
        verdicts: list[dict] = [],
        action: str = "",
        explanation: str = "",
        rate: float = 0.0,
        overall: str = "",
        lying: bool = False,
        checkLine: str = "",
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
    def toggle_lie -> None;
    def reset -> None;

    def node_at(nid: str) -> dict {
        for n in NODES {
            if n["id"] == nid {
                return n;
            }
        }
        return NODES[0];
    }

    def arc(a: str, b: str) -> str {
        p = node_at(a);
        q = node_at(b);
        mx = (p["x"] as int + (q["x"] as int)) / 2;
        my = min(p["y"] as int, q["y"] as int) - 40;
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
        if phase != "score" and phase != "audit" {
            return NEUTRAL;
        }
        v = verdict_of(eid);
        return TONE[v] if v in TONE else NEUTRAL;
    }

    def name_of(eid: str) -> str {
        return NAMES[eid] if eid in NAMES else eid;
    }

    # 1-based position in the player's chosen route, or "" if unpicked.
    def pick_no(nid: str) -> str {
        if mode != "free" {
            return "";
        }
        for (i, r) in enumerate(route) {
            if r == nid {
                return str(i + 1);
            }
        }
        return "";
    }

    return <main style={{"minHeight": "100vh", "background": "#08080A", "color": "#E6E6E9",
                         "fontFamily": SANS, "padding": "14px 22px"}}>
      <style>{CSS}</style>
      <div style={{"maxWidth": "1240px", "margin": "0 auto"}}>

        <div style={{"display": "flex", "justifyContent": "space-between",
                     "alignItems": "baseline"}}>
            <div style={{"display": "flex", "gap": "12px", "alignItems": "baseline",
                         "flexWrap": "wrap"}}>
                <span style={{"fontSize": "17px", "fontWeight": "700",
                              "letterSpacing": "0.02em"}}>PROVENANCE</span>
                <span style={{"fontSize": "13px", "color": "#8A8A94"}}>
                    An AI wrote reasons for a $4,200 payment. A checker with no AI in it
                    decides whether those reasons are real.
                </span>
            </div>
            <div style={{"textAlign": "right"}}>
                <div style={{"fontFamily": MONO, "fontSize": "20px", "fontWeight": "600",
                             "fontVariantNumeric": "tabular-nums",
                             "color": "#E6E6E9" if phase == "score" else "#3A3A44"}}>
                    {str(int(rate * 100)) + "%" if phase == "score" else "—"}
                </div>
                <div style={{"fontSize": "9.5px", "color": "#6B6B75",
                             "letterSpacing": "0.08em"}}>OF ITS REASONS HELD UP</div>
            </div>
        </div>

        {#* which half of the system is working right now -- the whole point *#}
        <div style={{"display": "flex", "gap": "0", "marginTop": "9px",
                     "borderRadius": "8px", "overflow": "hidden",
                     "border": "1px solid #17171C"}}>
            <div style={{"flex": "1", "padding": "6px 11px", "fontSize": "11px",
                         "background": "rgba(240,180,41,0.13)" if (phase == "walk" or phase == "oracle" or phase == "board") else "#0C0C10",
                         "color": "#F0B429" if (phase == "walk" or phase == "oracle" or phase == "board") else "#4A4A54",
                         "transition": "all 400ms"}}>
                <b>STEP 1 — the AI reads, then decides.</b>
                {"  It is guessing. It can be wrong, and it can misremember what it used."}
            </div>
            <div style={{"flex": "1", "padding": "6px 11px", "fontSize": "11px",
                         "borderLeft": "1px solid #17171C",
                         "background": "rgba(127,209,255,0.13)" if (phase == "audit" or phase == "score") else "#0C0C10",
                         "color": "#7FD1FF" if (phase == "audit" or phase == "score") else "#4A4A54",
                         "transition": "all 400ms"}}>
                <b>STEP 2 — the checker verifies.</b>
                {"  No AI. It just looks things up, and gives the same answer every time."}
            </div>
        </div>

        {#* the one line that says what is happening right now *#}
        <div className="lv-fade" key={note}
             style={{"fontSize": "15px", "color": "#F0B429", "marginTop": "7px",
                     "minHeight": "21px", "fontWeight": "500"}}>{note}</div>

        {#* ------- the journey ------- *#}
        <div style={{"marginTop": "5px", "border": "1px solid #17171C",
                     "borderRadius": "12px", "background": "#0B0B0E", "overflow": "hidden"}}>
            <svg viewBox={"0 0 " + str(STAGE_W) + " " + str(STAGE_H)}
                 style={{"width": "100%", "display": "block"}}>
                {for (i, n) in enumerate(NODES) {
                    <path key={"edge" + str(i)} d={arc("root", n["id"] as str)}
                          stroke="#1B1B21" strokeWidth="1.5" fill="none"
                          style={{"opacity": "0" if (n["id"] == "root" or n["id"] == "decision") else "1"}} />
                }}

                {for (i, sid) in enumerate(collected) {
                    <path key={"walk" + str(i)} className="lv-drawn"
                          d={arc(collected[i - 1] if i > 0 else "root", sid)}
                          stroke="#F0B429" strokeWidth="3" fill="none" strokeLinecap="round" />
                }}

                {for (i, n) in enumerate(NODES) {
                    <g key={"n" + str(i)}
                       style={{"cursor": "pointer" if (mode == "free" and phase == "picking") else "default"}}
                       onClick={lambda { toggle_node(n["id"] as str); }}>
                        <circle cx={n["x"]} cy={n["y"]}
                                r={"22" if (n["id"] == "root" or n["id"] == "decision") else "27"}
                                fill={tone_of(n["id"] as str)["fill"]}
                                stroke={"#F0B429" if pick_no(n["id"] as str) else tone_of(n["id"] as str)["stroke"]}
                                strokeWidth={"2.5" if pick_no(n["id"] as str) else "1.5"}
                                className={"lv-ring" if (walkerAt == n["id"] or auditAt == n["id"]) else ""}
                                style={{"transition": "fill 700ms, stroke 700ms"}} />
                        <text x={n["x"]} y={(n["y"] as int) + 4} textAnchor="middle"
                              style={{"fontFamily": MONO, "fontSize": "11px", "fontWeight": "700",
                                      "fill": "#F0B429" if pick_no(n["id"] as str) else tone_of(n["id"] as str)["text"],
                                      "pointerEvents": "none"}}>
                            {pick_no(n["id"] as str) if pick_no(n["id"] as str) else n["label"]}
                        </text>
                        <text x={n["x"]} y={(n["y"] as int) + 45} textAnchor="middle"
                              style={{"fontSize": "11px", "fill": "#9A9AA4", "pointerEvents": "none"}}>
                            {name_of(n["id"] as str) if (n["id"] != "root" and n["id"] != "decision") else ""}
                        </text>
                    </g>
                }}

                <circle r="10" fill="#F0B429"
                        cx={node_at(walkerAt)["x"]} cy={node_at(walkerAt)["y"]}
                        style={{"opacity": "1" if (phase == "walk" or phase == "oracle") else "0",
                                "transition": "cx 1400ms cubic-bezier(.4,0,.2,1), cy 1400ms cubic-bezier(.4,0,.2,1), opacity 400ms"}} />

                <rect width="16" height="16" fill="none" stroke="#7FD1FF" strokeWidth="2.5"
                      x={(node_at(auditAt)["x"] as int) - 8} y={(node_at(auditAt)["y"] as int) - 8}
                      style={{"opacity": "1" if phase == "audit" else "0",
                              "transition": "x 900ms linear, y 900ms linear, opacity 300ms"}} />
            </svg>

            {if phase == "audit" and checkLine {
                <div className="lv-fade" key={checkLine}
                     style={{"padding": "11px 18px", "borderTop": "1px solid #17171C",
                             "background": "rgba(127,209,255,0.07)", "textAlign": "center",
                             "fontFamily": MONO, "fontSize": "13px", "color": "#BFE6FF"}}>
                    {checkLine}
                </div>
            } else {
                <span key="nocheck" />
            }}

            {if phase == "oracle" {
                <div className="lv-fade" style={{"padding": "12px 18px", "borderTop": "1px solid #17171C",
                                                 "background": "#0E0E12", "textAlign": "center"}}>
                    <div style={{"fontSize": "15px", "color": "#F0B429", "fontWeight": "600"}}>
                        The AI is deciding now…
                    </div>
                    <div style={{"fontSize": "12.5px", "color": "#9A9AA4", "marginTop": "3px"}}>
                        It gets the words it read — but never which ones were confirmed true.
                    </div>
                    <div className="lv-scan" style={{"width": "180px", "height": "2px",
                                                     "background": "#F0B429", "margin": "9px auto 0"}} />
                </div>
            } else {
                <span key="noveil" />
            }}
        </div>

        {#* ------- every claim, readable, from the very start ------- *#}
        <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr 1fr 1fr",
                     "gap": "8px", "marginTop": "8px"}}>
            {for (i, e) in enumerate(evidence) {
                <div key={"ev" + str(i)}
                     style={{"border": "1px solid " + tone_of(e["id"] as str)["stroke"],
                             "background": tone_of(e["id"] as str)["fill"],
                             "borderRadius": "10px", "padding": "9px 11px",
                             "transition": "all 600ms",
                             "opacity": "1" if (walkerAt == e["id"] or phase != "walk") else "0.4"}}>
                    <div style={{"display": "flex", "justifyContent": "space-between",
                                 "alignItems": "baseline", "gap": "6px"}}>
                        <span style={{"fontSize": "12px", "fontWeight": "700",
                                      "color": "#E6E6E9"}}>{name_of(e["id"] as str)}</span>
                        <span style={{"fontFamily": MONO, "fontSize": "9px", "color": "#56D364",
                                      "letterSpacing": "0.06em"}}>
                            {"✓ READ" if (e["id"] in collected) else ""}
                        </span>
                    </div>
                    <div style={{"fontSize": "11.5px", "lineHeight": "1.45", "color": "#B4B4BE",
                                 "marginTop": "5px"}}>{e["content"]}</div>
                    {if verdict_of(e["id"] as str) {
                        <div style={{"fontFamily": MONO, "fontSize": "9.5px", "marginTop": "7px",
                                     "letterSpacing": "0.08em",
                                     "color": tone_of(e["id"] as str)["text"]}}>
                            {VERDICT_WORD[verdict_of(e["id"] as str)] if verdict_of(e["id"] as str) in VERDICT_WORD else ""}
                        </div>
                    } else {
                        <span key={"nv" + str(i)} />
                    }}
                </div>
            }}
        </div>

        {#* ------- the comparison, in plain words ------- *#}
        <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "8px",
                     "marginTop": "8px"}}>
            <div style={{"border": "1px solid #17171C", "borderRadius": "10px",
                         "padding": "8px 12px", "background": "#0C0C10"}}>
                <div style={{"fontSize": "10px", "color": "#6B6B75",
                             "letterSpacing": "0.08em"}}>WHAT IT ACTUALLY READ</div>
                <div style={{"fontSize": "13px", "color": "#56D364", "marginTop": "3px",
                             "minHeight": "18px"}}>
                    {", ".join([name_of(c) for c in collected]) if len(collected) > 0 else "nothing yet"}
                </div>
            </div>
            <div style={{"border": "1px solid #17171C", "borderRadius": "10px",
                         "padding": "8px 12px", "background": "#0C0C10"}}>
                <div style={{"fontSize": "10px", "color": "#6B6B75",
                             "letterSpacing": "0.08em"}}>WHAT IT SAID IT USED</div>
                <div style={{"fontSize": "13px", "color": "#F0B429", "marginTop": "3px",
                             "minHeight": "18px"}}>
                    {", ".join([name_of(c) for c in cited]) if len(cited) > 0 else "hasn't said yet"}
                </div>
            </div>
        </div>

        {#* ------- result ------- *#}
        {if phase == "score" {
            <div className="lv-pop" style={{"marginTop": "8px", "border": "1px solid #17171C",
                         "borderRadius": "10px", "padding": "10px 13px", "background": "#0C0C10"}}>
                <div style={{"fontSize": "10px", "color": "#6B6B75", "letterSpacing": "0.08em",
                             "marginBottom": "5px"}}>THE AI'S OWN WORDS</div>
                <div style={{"fontSize": "13px", "lineHeight": "1.5", "color": "#C9C9D1"}}>
                    <b style={{"color": "#E6E6E9"}}>{"It chose to " + action.upper() + ". "}</b>
                    {explanation}
                </div>
                <div style={{"fontSize": "10px", "color": "#6B6B75", "letterSpacing": "0.08em",
                             "marginTop": "10px", "marginBottom": "5px"}}>
                    WHAT THE CHECKER FOUND — NO AI INVOLVED
                </div>
                <div style={{"display": "flex", "gap": "7px", "flexWrap": "wrap", "marginTop": "9px"}}>
                    {for (i, v) in enumerate(verdicts) {
                        <span key={"v" + str(i)} className="lv-pop"
                              style={{"fontSize": "11px", "padding": "5px 10px", "borderRadius": "7px",
                                      "color": TONE[v["verdict"] as str]["text"] if (v["verdict"] as str) in TONE else "#8A8A94",
                                      "border": "1px solid " + (TONE[v["verdict"] as str]["stroke"] if (v["verdict"] as str) in TONE else "#2B2B33"),
                                      "background": TONE[v["verdict"] as str]["fill"] if (v["verdict"] as str) in TONE else "#131317",
                                      "animationDelay": str(220 * i) + "ms"}}>
                            {name_of(str(v["id"])) + " — " + (VERDICT_PLAIN[v["verdict"] as str] if (v["verdict"] as str) in VERDICT_PLAIN else "")}
                        </span>
                    }}
                </div>
            </div>
        } else {
            <span key="noscore" />
        }}

        {#* ------- controls: every button says what it does ------- *#}
        <div style={{"display": "flex", "gap": "8px", "alignItems": "center",
                     "marginTop": "9px", "flexWrap": "wrap"}}>
            {if mode == "free" {
                <div key="freebar" style={{"display": "flex", "gap": "9px", "alignItems": "center",
                                           "flexWrap": "wrap"}}>
                    <span style={{"fontSize": "13px", "color": "#F0B429"}}>
                        {"Click circles to pick what it reads — order matters.  (" + str(len(route)) + " picked)"}
                    </span>
                    <button onClick={commit_free} disabled={busy or len(route) == 0}
                            style={{"fontSize": "12px", "padding": "9px 16px", "borderRadius": "8px",
                                    "border": "1px solid #F0B429", "fontWeight": "600",
                                    "background": "#F0B429" if (len(route) > 0 and not busy) else "#16161B",
                                    "color": "#08080A" if (len(route) > 0 and not busy) else "#5A5A64",
                                    "cursor": "pointer" if (len(route) > 0 and not busy) else "default"}}>
                        {"RUN IT"}
                    </button>
                    <button onClick={toggle_lie} disabled={busy}
                            style={{"fontSize": "12px", "padding": "9px 14px", "borderRadius": "8px",
                                    "border": "1px solid " + ("#F85149" if lying else "#2B2B33"),
                                    "background": "rgba(248,81,73,0.16)" if lying else "#101014",
                                    "color": "#FF7B72" if lying else "#9A9AA4", "cursor": "pointer"}}>
                        {"MAKE IT LIE ✓" if lying else "MAKE IT LIE"}
                    </button>
                </div>
            } else {
                <button key="guided" onClick={start_guided} disabled={busy}
                        style={{"fontSize": "13px", "padding": "10px 20px", "borderRadius": "8px",
                                "border": "1px solid #E6E6E9", "fontWeight": "600",
                                "background": "#E6E6E9" if not busy else "#16161B",
                                "color": "#08080A" if not busy else "#5A5A64",
                                "cursor": "pointer" if not busy else "default"}}>
                    {"▶  WATCH IT HAPPEN"}
                </button>
            }}
            <button onClick={start_free} disabled={busy}
                    style={{"fontSize": "12px", "padding": "9px 16px", "borderRadius": "8px",
                            "border": "1px solid #2B2B33", "background": "#101014",
                            "color": "#C9C9D1", "cursor": "pointer"}}>
                {"LET ME TRY"}
            </button>
            <button onClick={reset} disabled={busy}
                    style={{"fontSize": "12px", "padding": "9px 14px", "borderRadius": "8px",
                            "border": "1px solid #1F1F26", "background": "transparent",
                            "color": "#6B6B75", "cursor": "pointer"}}>
                {"START OVER"}
            </button>
        </div>
      </div>
    </main>;
}
