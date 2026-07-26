"""Provenance -- web-grounded evidence.

Everything above this file establishes `verified` by fiat: we set the flag in
the seed, and the honest answer to "how do you know the flag is right?" was
"it was established before the agent ran." True, but it is still an assertion.

This file removes the assertion. A WebEvidence node carries a claim AND the
URL it is attributed to, and its `verified` value is not typed by anyone -- it
is derived by fetching the page and checking whether the claim is actually
present in what came back. Same rule as every other evidence source: the value
is fixed before the agent reasons, and the agent never sees it.

That makes the trust chain end somewhere real. A `grounded` verdict now traces
to a specific URL, fetched at a specific moment, returning a specific number of
characters, in which the claimed text literally appeared. Nothing in that chain
is a judgement.

No model is involved anywhere in this file, by design and by grep -- the phrase
that would delegate to one does not appear here or in its annex. This is the
same discipline as gate.jac: the parts that decide what is true are the parts
that must be checkable without trusting us.

Additive. models.jac, reason.jac, agent.jac and gate.jac are untouched;
WebEvidence subclasses Evidence rather than changing it, which is why the
existing `[-->[?:Evidence]]` filter and Evidence.hand_off both still apply
(verified: the filter matches the subclass and hand_off fires for it).
"""

import os;
import json;
import urllib.request as urlreq;

import from models { Evidence }


glob SCRAPE_ENDPOINT: str = "https://api.firecrawl.dev/v2/scrape";

# One fetch per URL per process. Two claims about the same page must not cost
# two network round trips -- and on stage, must not cost two waits.
glob _PAGE_CACHE: dict[str, Page] = {};


obj Page {
    has ok: bool,
        markdown: str,
        final_url: str,
        note: str;
}


obj Attestation {
    """The record of how one claim's `verified` value was established."""
    has claim: str,
        url: str,
        final_url: str,
        found: bool,
        source_chars: int,
        note: str;
}


node WebEvidence(Evidence) {
    # Every field defaulted: Evidence ends with a defaulted `verified`, and a
    # non-defaulted field here would follow it (E2004).
    #
    # `final_url` is separate from `url` on purpose. Fetching
    # /wiki/Business_email_compromise returns /wiki/Email_spoofing -- a real
    # redirect hit while building this. Recording only the requested URL would
    # mean the audit trail names a page we never actually read.
    has url: str = "",
        final_url: str = "",
        source_chars: int = 0,
        check_note: str = "";
}


"""Fetch a URL's main content as markdown. Cached per process."""
def fetch(url: str) -> Page;

"""Lowercase, drop markdown emphasis, collapse whitespace."""
def normalize(text: str) -> str;

"""Fetch `url` and record whether `claim` literally appears in it."""
def attest(claim: str, url: str) -> Attestation;

"""Build a WebEvidence node whose `verified` is the attestation's result."""
def web_evidence(source_id: str, claim: str, url: str) -> WebEvidence;
