"""Provenance -- claim checker, one claim at a time.

    jac run checkclaim.jac <url> "<claim>"

A thin argument-reading shell over the exact attestation path that
webcase.jac uses. There is no verification logic in this file: it reads two
strings from the command line, hands them to `attest` in web.jac, and prints
what comes back. If this disagrees with webcase.jac, one of them is broken,
because both call the same function.

Exit status is the verdict, so it composes with anything: 0 when the claim is
present in the fetched page, 1 when it is not or the fetch failed.

Additive. Nothing else in the project imports this file.
"""

import sys;

import from web { attest }


with entry:__main__ {
    if len(sys.argv) < 3 {
        print("usage: jac run checkclaim.jac <url> \"<claim>\"");
        print("");
        print("  Fetches <url> and reports whether <claim> appears in it.");
        print("  Requires FIRECRAWL_API_KEY in the environment.");
        sys.exit(2);
    }

    url = sys.argv[1];
    claim = sys.argv[2];

    a = attest(claim, url);

    print("");
    print("  claim        : \"" + a.claim + "\"");
    print("  requested    : " + a.url);
    print("  actually read: " + (a.final_url if a.final_url else "(fetch failed)")
          + ("   (" + str(a.source_chars) + " chars)" if a.source_chars else ""));
    print("  verified     : " + str(a.found));
    print("  note         : " + a.note);
    print("");

    sys.exit(0 if a.found else 1);
}
