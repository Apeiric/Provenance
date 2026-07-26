"""Implementation annex for web.jac.

No model is called here. Fetch, normalise, substring.
"""

impl fetch(url: str) -> Page {
    if url in _PAGE_CACHE {
        return _PAGE_CACHE[url];
    }

    key = os.environ.get("FIRECRAWL_API_KEY", "");
    if not key {
        # Fail closed. A missing key must never read as "claim confirmed".
        page = Page(ok=False, markdown="", final_url="",
                    note="FIRECRAWL_API_KEY not set");
        _PAGE_CACHE[url] = page;
        return page;
    }

    body = json.dumps({
        "url": url,
        "formats": ["markdown"],
        "onlyMainContent": True
    }).encode();

    req = urlreq.Request(
        SCRAPE_ENDPOINT,
        data=body,
        headers={
            "Authorization": "Bearer " + key,
            "Content-Type": "application/json"
        },
        method="POST"
    );

    try {
        # Not `with urlreq.urlopen(...) as r`: the stdlib handle types as Any
        # and jac check rejects Any in a with-statement (E1091/E1092).
        resp = urlreq.urlopen(req, timeout=90);
        raw = resp.read().decode();
        resp.close();
        payload = json.loads(raw);
    } except Exception as e {
        # Network failure, 402, 429, timeout -- all land here, and all fail
        # closed. This is the distinction that matters most in this file:
        # "we could not check" is not "we checked and it was fine". The note
        # keeps the two apart in the audit trail instead of collapsing them
        # into a single False.
        page = Page(ok=False, markdown="", final_url="",
                    note="fetch failed: " + str(e));
        _PAGE_CACHE[url] = page;
        return page;
    }

    data = payload.get("data", {});
    markdown = str(data.get("markdown", "") or "");
    meta = data.get("metadata", {}) or {};

    page = Page(
        ok=bool(payload.get("success")) and len(markdown) > 0,
        markdown=markdown,
        final_url=str(meta.get("url", url) or url),
        note="fetched"
    );
    _PAGE_CACHE[url] = page;
    return page;
}


impl normalize(text: str) -> str {
    # Deliberately conservative. Case and markdown emphasis are formatting, so
    # removing them is safe; anything more aggressive (stemming, punctuation
    # stripping, fuzzy matching) would start letting near-misses through, and
    # a check that accepts near-misses is the thing this project exists to
    # replace. `" ".join(split())` collapses every whitespace run, so a claim
    # still matches across a line wrap in the source.
    lowered = text.lower().replace("*", "").replace("_", "").replace("`", "");
    return " ".join(lowered.split());
}


impl attest(claim: str, url: str) -> Attestation {
    page = fetch(url);

    if not page.ok {
        return Attestation(
            claim=claim, url=url, final_url="", found=False,
            source_chars=0, note=page.note
        );
    }

    found = normalize(claim) in normalize(page.markdown);

    return Attestation(
        claim=claim,
        url=url,
        final_url=page.final_url,
        found=found,
        source_chars=len(page.markdown),
        note="claim present in fetched content" if found
             else "claim absent from fetched content"
    );
}


impl web_evidence(source_id: str, claim: str, url: str) -> WebEvidence {
    a = attest(claim, url);
    return WebEvidence(
        source_id=source_id,
        content=claim,
        verified=a.found,      # <- established by the fetch, not by us
        url=a.url,
        final_url=a.final_url,
        source_chars=a.source_chars,
        check_note=a.note
    );
}
