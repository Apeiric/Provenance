"""Smoke tests for the server-side graph API."""

test "posting a message returns typed evidence" {
    result = root spawn PostMessage(
        author="setup-check", text="Jac backend is operational"
    );

    assert len(result.reports) == 1;
    assert result.reports[0].author == "setup-check";
    assert result.reports[0].text == "Jac backend is operational";
}
