#!/usr/bin/env bash
#
# test-locally.sh - validate the Action's segspec wrapper outside of CI.
#
# What this does:
#   1. Detects local OS+arch.
#   2. Downloads the segspec binary from GitHub Releases (matches the version
#      the Action's `version` input would resolve to).
#   3. Runs `segspec analyze` on examples/compose-2service.
#   4. Asserts the output mentions postgres AND that the JSON format returns
#      at least one dependency.
#
# Use this before pushing a new Action release to confirm the binary your
# Action will download actually works on the example fixtures.
#
# Usage:
#   ./test-locally.sh              # uses latest segspec release
#   SEGSPEC_VERSION=v0.6.0 ./test-locally.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="${REPO_ROOT}/examples/compose-2service"
VERSION="${SEGSPEC_VERSION:-latest}"

if [ ! -d "${EXAMPLE_DIR}" ]; then
  echo "FAIL: example directory not found: ${EXAMPLE_DIR}" >&2
  exit 1
fi

# --- Detect platform (mirrors action.yml's "Detect runner platform" step) ---
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch_raw="$(uname -m)"
case "${arch_raw}" in
  x86_64|amd64)  arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) echo "FAIL: unsupported arch: ${arch_raw}" >&2; exit 1 ;;
esac
case "${os}" in
  linux|darwin) ;;
  *) echo "FAIL: unsupported OS: ${os} (linux/darwin only)" >&2; exit 1 ;;
esac

echo "==> Platform: ${os}/${arch}, segspec version: ${VERSION}"

# --- Download the binary into a temp dir (mirrors the Action's install step) ---
tmpdir="$(mktemp -d -t segspec-localtest-XXXXXX)"
trap 'rm -rf "${tmpdir}"' EXIT

if [ "${VERSION}" = "latest" ]; then
  url="https://github.com/dormstern/segspec/releases/latest/download/segspec-${os}-${arch}"
else
  url="https://github.com/dormstern/segspec/releases/download/${VERSION}/segspec-${os}-${arch}"
fi

echo "==> Fetching ${url}"
curl -fsSL "${url}" -o "${tmpdir}/segspec"
chmod +x "${tmpdir}/segspec"

SEGSPEC="${tmpdir}/segspec"

echo "==> segspec version:"
"${SEGSPEC}" --version || true   # tolerate older builds without --version

# --- Smoke 1: summary on fixture, must mention postgres ---
echo "==> Test 1: analyze --format summary on ${EXAMPLE_DIR}"
summary_out="${tmpdir}/summary.txt"
"${SEGSPEC}" analyze "${EXAMPLE_DIR}" --format summary --output "${summary_out}"

if [ ! -s "${summary_out}" ]; then
  echo "FAIL: summary output is empty" >&2
  exit 1
fi

if ! grep -qi postgres "${summary_out}"; then
  echo "FAIL: summary did not mention postgres" >&2
  echo "--- summary ---"
  cat "${summary_out}"
  exit 1
fi

if grep -qi "no network dependencies found" "${summary_out}"; then
  echo "FAIL: got the empty-result sentinel; fixture should produce a dep" >&2
  cat "${summary_out}"
  exit 1
fi

echo "    OK: summary mentions postgres"

# --- Smoke 2: json format must contain at least one dependency ---
echo "==> Test 2: analyze --format json must have non-empty dependencies"
json_out="${tmpdir}/deps.json"
"${SEGSPEC}" analyze "${EXAMPLE_DIR}" --format json --output "${json_out}"

if [ ! -s "${json_out}" ]; then
  echo "FAIL: json output is empty" >&2
  exit 1
fi

python3 - "${json_out}" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
deps = data.get("dependencies") or []
if not deps:
    print("FAIL: json had zero dependencies; got:", json.dumps(data))
    sys.exit(1)
print(f"    OK: json has {len(deps)} dependency(ies)")
PY

# --- Smoke 3: netpol format must produce something parseable as YAML-ish ---
echo "==> Test 3: analyze --format netpol must produce non-empty output"
netpol_out="${tmpdir}/netpol.yaml"
"${SEGSPEC}" analyze "${EXAMPLE_DIR}" --format netpol --output "${netpol_out}"
if [ ! -s "${netpol_out}" ]; then
  echo "FAIL: netpol output is empty" >&2
  exit 1
fi
if ! grep -qi "kind: NetworkPolicy" "${netpol_out}"; then
  echo "FAIL: netpol output did not contain 'kind: NetworkPolicy'" >&2
  cat "${netpol_out}"
  exit 1
fi
echo "    OK: netpol output contains a NetworkPolicy kind"

echo ""
echo "All local smoke tests passed."
echo "Next: open PUBLISH.md and follow the runbook."
