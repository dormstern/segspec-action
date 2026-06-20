# Changelog

All notable changes to `dormstern/segspec-action` are tracked here. The Action follows [Semantic Versioning](https://semver.org/). Pin to `@v1` for the latest non-breaking 1.x release, or `@v1.0.0` for full reproducibility.

## v1.0.1 - 2026-06-19

Critical fix: the binary download in v1.0.0 requested a raw-binary asset name that the segspec release does not publish, so every run failed. v1.0.1 downloads the correct release archive and verifies it before running.

### Fixed
- Download the goreleaser release archive (`segspec_<ver>_<os>_<arch>.tar.gz`) and extract it, instead of a non-existent raw-binary URL. `latest` now resolves to a concrete release tag via the GitHub API.

### Added
- Fail-closed SHA-256 verification of the downloaded archive against the release `checksums.txt` before the binary is executed.
- `annotate` input (default `true`): writes the run output to the job summary and annotates detected drift.
- `github-token` input (default `${{ github.token }}`): read-only, used only to resolve the `latest` release tag without hitting unauthenticated rate limits.
- `version` output reporting the resolved segspec version.

### Changed
- The license key is no longer written to a step output (step outputs are not masked); it is resolved directly where it is used.
- README documents least-privilege `permissions:` in every example, the SARIF → Security tab recipe, and the checksum-verification guarantee.

### Security
- Self-test workflow actions are pinned to commit SHAs; Dependabot keeps them current.

## v1.0.0 - 2026-05-04

Initial public release. Wraps `segspec analyze` and `segspec diff` from the [`segspec`](https://github.com/dormstern/segspec) CLI.

### Added
- Composite Action that downloads the `segspec` binary from GitHub Releases and runs it on the runner. Configs never leave the runner.
- `path` input for the directory or GitHub URL to analyze.
- `format` input supporting all v0.6.0 output formats: `summary`, `netpol`, `per-service`, `default-deny`, `audit`, `cilium`, `all`, `evidence`, `evidence-bundle`, `evidence-bundle-sarif`, `json`.
- `baseline` input — when set, runs `segspec diff <baseline> <path>` for drift detection (paid).
- `exit-code` input — fail the action when diff detects changes, for PR gating (paid).
- `license-key` input with fallback to the `SEGSPEC_LICENSE_KEY` env var.
- `version` input to pin a specific segspec release (default: `latest`).
- `output-file` input to write structured output to a file consumable by later workflow steps.
- `exit-code` and `output-file` outputs for downstream steps.
- License gate: paid features (`format: evidence | per-service | evidence-bundle | evidence-bundle-sarif`, `baseline:`, `exit-code: true`) fail fast with exit code 78 and a clear error if no license is present.
- Platform support: `ubuntu-latest`, `macos-latest`, plus arm64 variants of both.
- Self-test workflow at `.github/workflows/test.yml` running on every push and PR.
- Local validation script `test-locally.sh` for pre-publish smoke testing.

### Tier policy
- Free, forever: `summary`, `netpol`, `json`, `all`, `default-deny`, `audit`, `cilium`.
- License required: `evidence`, `per-service`, `evidence-bundle`, `evidence-bundle-sarif`, `baseline:` (diff mode), `exit-code: true`.

### Wraps
- `segspec` CLI v0.6.0 by default. Pin a different version via the `version` input. Earlier segspec versions (v0.5.x) are supported with the caveat that formats added in v0.6.0 (`default-deny`, `audit`, `cilium`, `evidence-bundle`, `evidence-bundle-sarif`) will return an "unknown format" error.

### Not yet wrapped (planned for follow-up releases)
- `segspec snapshot`, `segspec validate`, `segspec coverage`, `segspec explain` — these v0.6.0 subcommands are reachable via the binary on `$PATH` after this Action runs, but don't have first-class inputs yet.
