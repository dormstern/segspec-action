# segspec-action

Static config-to-NetworkPolicy extraction in CI. The Action runs entirely on the GitHub-hosted runner. Your configs never leave the runner. No telemetry. No agents. No observation period.

Wraps the [segspec](https://github.com/dormstern/segspec) Go CLI. The binary is downloaded from GitHub Releases on each run.

## Tiers

| Capability | Free | License required |
|---|---|---|
| `format: summary` | yes | |
| `format: netpol` | yes | |
| `format: json` | yes | |
| `format: all` | yes | |
| `format: default-deny` | yes | |
| `format: audit` | yes | |
| `format: cilium` | yes | |
| `format: evidence` | | yes |
| `format: per-service` | | yes |
| `format: evidence-bundle` | | yes |
| `format: evidence-bundle-sarif` | | yes |
| `baseline:` (diff mode) | | yes |
| `exit-code: true` | | yes |

A license key is required for paid features. Set it as the repo secret `SEGSPEC_LICENSE_KEY` (the Action picks it up automatically via env). Get a key at <https://segspec.dev/pricing>.

## Inputs

| Name | Default | Description |
|---|---|---|
| `path` | `.` | Directory or GitHub URL to analyze. |
| `format` | `summary` | `summary`, `netpol`, `per-service`, `default-deny`, `audit`, `cilium`, `all`, `evidence`, `evidence-bundle`, `evidence-bundle-sarif`, `json`. |
| `baseline` | `""` | Path to baseline JSON. When set, runs `segspec diff <baseline> <path>`. Paid. |
| `exit-code` | `false` | Fail the action when diff detects changes. Paid. Only valid with `baseline`. |
| `license-key` | `""` | Falls back to `env.SEGSPEC_LICENSE_KEY`. |
| `version` | `latest` | segspec release tag (e.g. `v0.5.0`). |
| `output-file` | `""` | Write structured output to a file. |

## Example: free public-repo audit

```yaml
name: segspec
on: [push]
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dormstern/segspec-action@v1
        with:
          path: .
          format: summary
```

## Example: free public-repo, write netpols to a file

```yaml
name: segspec netpols
on:
  push:
    branches: [main]
jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
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

## Example: paid private-repo PR gate

Fail PRs when network dependencies drift from the committed baseline.

```yaml
name: netpol drift
on: [pull_request]
jobs:
  diff:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dormstern/segspec-action@v1
        env:
          SEGSPEC_LICENSE_KEY: ${{ secrets.SEGSPEC_LICENSE_KEY }}
        with:
          path: .
          baseline: deps-baseline.json
          exit-code: true
```

To regenerate the baseline:

```bash
segspec analyze . --format json > deps-baseline.json
git add deps-baseline.json && git commit -m "refresh segspec baseline"
```

## License-key secret setup

1. Repo settings -> Secrets and variables -> Actions -> New repository secret.
2. Name: `SEGSPEC_LICENSE_KEY`. Value: your license key.
3. Pass it into the Action via the env block as shown above.

The key is read once on the runner and forwarded to the segspec binary via env. Nothing else leaves the runner.

## Outputs

| Name | Description |
|---|---|
| `exit-code` | Numeric exit status of the segspec invocation. |
| `output-file` | Path to the output file, when `output-file` was set. |

## Versioning

This Action follows semver. Pin to a major (`@v1`) for stability or a tag (`@v1.0.0`) for reproducibility. The `version` input pins the underlying segspec binary independently.

## Roadmap

`v1.0.0` of this Action wraps `segspec analyze` (with `segspec diff` as the baseline mode). segspec gained four additional subcommands in v0.6.0 that are not yet wrapped here and are planned for follow-up Action releases:

- `segspec snapshot` — deterministic dependency snapshots with provenance.
- `segspec validate` — self-check rendered NetworkPolicy YAML.
- `segspec coverage` — services-without-NetworkPolicy report.
- `segspec explain` — per-dependency provenance traceback.

Until those land, you can run them directly from the segspec binary downloaded by this Action — it's on `$PATH` for any subsequent step in the same job.

## License

[MIT](LICENSE).
