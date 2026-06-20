# segspec-action

[![Marketplace](https://img.shields.io/badge/Marketplace-segspec-blue?logo=github)](https://github.com/marketplace/actions/segspec)
[![self-test](https://github.com/dormstern/segspec-action/actions/workflows/test.yml/badge.svg)](https://github.com/dormstern/segspec-action/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Static config-to-NetworkPolicy extraction in CI. The Action runs entirely on the GitHub-hosted runner. Your configs never leave the runner. No telemetry. No agents. No observation period.

Wraps the [segspec](https://github.com/dormstern/segspec) Go CLI. The binary is downloaded from GitHub Releases and **its SHA-256 is verified against the release `checksums.txt` before execution** — the Action fails closed if the checksum does not match.

![segspec analyzing Sentry self-hosted](https://raw.githubusercontent.com/dormstern/segspec/main/docs/demos/sentry-scan.gif)

> 411 network dependencies across 70+ services in 11ms — each traced to the exact config line that declared it. No agents, no runtime, no observation period.

## Quick start

```yaml
name: segspec
on: [push]
permissions:
  contents: read
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dormstern/segspec-action@v1
        with:
          path: .
          format: summary
```

The run output is written to the workflow **job summary** automatically.

## Tiers

| Capability | Free | License required |
|---|---|---|
| `summary`, `netpol`, `json`, `all`, `default-deny`, `audit`, `cilium` | yes | |
| `evidence`, `per-service`, `evidence-bundle`, `evidence-bundle-sarif` | | yes |
| `baseline:` (diff mode) | | yes |
| `exit-code: true` (fail on drift) | | yes |

Set the license key as the repo secret `SEGSPEC_LICENSE_KEY`. Get a key at <https://segspec.dev/pricing>.

## Inputs

| Name | Default | Description |
|---|---|---|
| `path` | `.` | Directory or GitHub URL to analyze. |
| `format` | `summary` | Output format (see tiers above). |
| `baseline` | `""` | Path to baseline JSON. When set, runs `segspec diff <baseline> <path>`. Paid. |
| `exit-code` | `false` | Fail the action when diff detects changes. Paid. Only valid with `baseline`. |
| `license-key` | `""` | Falls back to `env.SEGSPEC_LICENSE_KEY`. |
| `version` | `latest` | segspec release tag (e.g. `v0.6.0`). |
| `output-file` | `""` | Write structured output to a file. |
| `annotate` | `true` | Write a run summary to the job summary and annotate detected drift. |
| `github-token` | `${{ github.token }}` | Read-only token used only to resolve the `latest` release tag. |

## Outputs

| Name | Description |
|---|---|
| `exit-code` | Numeric exit status of the segspec invocation (`0` ok, `1` changes detected with `--exit-code`, other = error). |
| `output-file` | Path to the output file, when `output-file` was set. |
| `version` | The resolved segspec version that was installed. |

## Example: generate NetworkPolicies and commit them

```yaml
name: segspec netpols
on:
  push:
    branches: [main]
permissions:
  contents: write   # needed only to commit the generated policies
jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dormstern/segspec-action@v1
        with:
          path: .
          format: netpol
          output-file: k8s/network-policies.yaml
      - name: Commit policy
        run: |
          git add k8s/network-policies.yaml
          git diff --cached --quiet || {
            git config user.name  "segspec-bot"
            git config user.email "segspec-bot@users.noreply.github.com"
            git commit -m "update network policies [segspec]"
            git push
          }
```

## Example: fail PRs on network drift (paid)

Catch an added dependency or a removed one in review, before it reaches the cluster:

![segspec diff catching a network change](https://raw.githubusercontent.com/dormstern/segspec/main/docs/demos/diff-demo.gif)

```yaml
name: netpol drift
on: [pull_request]
permissions:
  contents: read
jobs:
  diff:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dormstern/segspec-action@v1
        env:
          SEGSPEC_LICENSE_KEY: ${{ secrets.SEGSPEC_LICENSE_KEY }}
        with:
          path: .
          baseline: deps-baseline.json
          exit-code: true
```

Regenerate the baseline:

```bash
segspec analyze . --format json > deps-baseline.json
git add deps-baseline.json && git commit -m "refresh segspec baseline"
```

## Example: publish evidence to the Security tab (paid)

`evidence-bundle-sarif` emits SARIF that GitHub renders as code-scanning alerts, so each network dependency lands in the **Security → Code scanning** tab with its source `file:line`.

![segspec evidence output showing the config line behind each dependency](https://raw.githubusercontent.com/dormstern/segspec/main/docs/demos/evidence-demo.gif)

```yaml
name: segspec evidence
on: [push]
permissions:
  contents: read
  security-events: write   # required to upload SARIF
jobs:
  evidence:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dormstern/segspec-action@v1
        env:
          SEGSPEC_LICENSE_KEY: ${{ secrets.SEGSPEC_LICENSE_KEY }}
        with:
          path: .
          format: evidence-bundle-sarif
          output-file: segspec.sarif
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: segspec.sarif
```

## Verified, reproducible runs

- **Integrity**: the downloaded binary's SHA-256 is checked against the release `checksums.txt`; a mismatch fails the run before the binary executes.
- **Pin for reproducibility**: pin this Action to a full commit SHA (e.g. `dormstern/segspec-action@<sha>`) and pin `actions/checkout` likewise. Dependabot keeps pins current.
- **Pin the CLI**: the `version` input pins the underlying segspec binary independently of the Action version.

## License-key secret setup

1. Repo settings → Secrets and variables → Actions → New repository secret.
2. Name: `SEGSPEC_LICENSE_KEY`. Value: your license key.
3. Pass it via the `env` block as shown in the paid examples.

The key is read once on the runner and forwarded to the segspec binary via env. Nothing else leaves the runner.

## Runner support

Linux and macOS runners (amd64 + arm64). Windows runner support is tracked in [issues](https://github.com/dormstern/segspec-action/issues).

## Versioning

Pin to a major (`@v1`) for stability, a tag (`@v1.0.1`) or a commit SHA for reproducibility.

## License

[MIT](LICENSE).
