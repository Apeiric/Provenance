#!/usr/bin/env bash
set -euo pipefail

port="${1:-8099}"
log_file="$(mktemp)"
response_file="$(mktemp)"
server_pid=""

cleanup() {
    if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -f "$log_file" "$response_file"
}
trap cleanup EXIT

if ! command -v jac >/dev/null 2>&1; then
    echo "jac is not on PATH; start a fresh WSL shell and retry." >&2
    exit 1
fi

jac start main.jac --port "$port" >"$log_file" 2>&1 &
server_pid="$!"

for _ in {1..45}; do
    if curl --fail --silent --show-error \
        "http://127.0.0.1:${port}/" \
        --output "$response_file"; then
        echo "Runtime verification passed: HTTP $(wc -c <"$response_file") bytes on port ${port}."
        exit 0
    fi

    if ! kill -0 "$server_pid" 2>/dev/null; then
        echo "Jac server exited before becoming ready." >&2
        cat "$log_file" >&2
        exit 1
    fi
    sleep 1
done

echo "Jac server did not become ready within 45 seconds." >&2
cat "$log_file" >&2
exit 1
