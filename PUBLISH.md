# Publishing `dormstern/segspec-action@v1` to the GitHub Marketplace

Step-by-step runbook for releasing v1.0.0. Follow in order. Estimated time: 25 minutes (excluding Marketplace review wait).

This Action lives in `gh-action/` inside the segspec monorepo for development, but the published Action must live in its own public repo: `dormstern/segspec-action`. GitHub Marketplace requires an Action to be at the root of its own repo and the repo to be public.

---

## 0. Pre-flight (do this first)

Make sure the local fixture and binary actually work together before you publish anything.

```bash
cd /path/to/segspec/gh-action
chmod +x test-locally.sh
./test-locally.sh
```

This downloads the latest segspec binary, runs it on `examples/compose-2service`, and asserts the output is non-empty. If this fails, **stop** — debug locally before going public.

To pin to a specific segspec version:

```bash
SEGSPEC_VERSION=v0.6.0 ./test-locally.sh
```

You also need a published segspec release with `segspec-linux-amd64`, `segspec-linux-arm64`, `segspec-darwin-amd64`, `segspec-darwin-arm64` binaries attached, otherwise the Action's download step will 404. Confirm at <https://github.com/dormstern/segspec/releases/latest>.

---

## 1. Create the public repo on GitHub

1. Go to <https://github.com/new>.
2. Owner: `dormstern`. Repository name: `segspec-action`. Visibility: **Public**.
3. Description: `Static config-to-NetworkPolicy extraction in CI. Wraps the segspec CLI.`
4. Do **not** initialize with a README, .gitignore, or license — you're pushing the existing `gh-action/` contents.
5. Click "Create repository".

---

## 2. Push the Action contents to the new repo

From the segspec repo root:

```bash
cp -r gh-action/. /tmp/segspec-action/
cd /tmp/segspec-action
git init
git add .
git commit -m "Initial release v1.0.0"
git branch -M main
git remote add origin git@github.com:dormstern/segspec-action.git
git push -u origin main
```

If you prefer HTTPS over SSH, swap the remote URL for `https://github.com/dormstern/segspec-action.git`.

Verify on github.com that `action.yml`, `README.md`, `LICENSE`, `examples/`, and `.github/workflows/test.yml` are all visible at the repo root.

---

## 3. Tag and create the v1.0.0 release

You need **both** a `v1.0.0` immutable tag and a floating `v1` major-version tag. Marketplace listings tie to a release, but consumers will pin `@v1` for stability.

```bash
cd /tmp/segspec-action
git tag -a v1.0.0 -m "v1.0.0 - initial release"
git tag -a v1 -m "v1 (floating major)"
git push origin v1.0.0
git push origin v1
```

Then on github.com:

1. Go to <https://github.com/dormstern/segspec-action/releases/new>.
2. **Choose a tag**: select `v1.0.0`.
3. **Release title**: `v1.0.0 - Initial release`.
4. **Description**: paste the v1.0.0 entry from `CHANGELOG.md` verbatim.
5. **Check the box**: "Publish this Action to the GitHub Marketplace". (This box only appears if `action.yml` validates and the repo is public.)
6. Accept the GitHub Marketplace Developer Agreement if prompted.
7. **Primary category**: `Security`.
8. **Secondary category**: `Continuous integration`.
9. Click "Publish release".

If the Marketplace checkbox is missing or grayed out, the most common reasons are:
- `action.yml` failed schema validation (check the Actions tab for any error).
- Repo is private — flip it to public.
- `name`, `description`, `author`, or `branding` field is missing in `action.yml`. (All four are present in this Action.)

---

## 4. Verify the Marketplace listing

1. Wait 1-3 minutes after publishing the release.
2. Visit <https://github.com/marketplace/actions/segspec> (the slug is derived from `action.yml` `name:` field — `name: segspec` -> `marketplace/actions/segspec`).
3. Confirm the listing shows the README, the `Use latest version` button, and the `dormstern/segspec-action@v1.0.0` snippet.
4. If the listing 404s after 5 minutes, GitHub may still be reviewing — listings publish automatically for verified publishers but can take up to 30 minutes the first time.

---

## 5. Smoke-test against a real consumer repo

Pick (or create) any repo with a `docker-compose.yml`. Add this workflow:

```yaml
# .github/workflows/segspec-smoke.yml
name: segspec smoke
on: [workflow_dispatch]
jobs:
  segspec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dormstern/segspec-action@v1
        with:
          path: .
          format: summary
```

Trigger it manually from the Actions tab. The job should:
- Pull the segspec binary from the latest release.
- Print a summary of dependencies in the workflow log.
- Exit 0.

If it exits 78, you hit the paid-feature gate (you asked for `evidence` or `per-service` without a license — switch to `summary`).

If the binary download 404s, the segspec release is missing one of the required platform binaries — fix that in the segspec repo's release, then retry.

---

## 6. Post-publish hygiene

- Pin the floating `v1` tag forward each future release: after publishing `v1.0.1`, force-push the `v1` tag to point at `v1.0.1`. (Only force-push the floating major tag; never the immutable patch tags.)
- Bump `CHANGELOG.md` for every release.
- Re-run `test-locally.sh` before tagging anything, and re-run the smoke workflow in this repo's `.github/workflows/test.yml` against `main`.
- The Marketplace listing auto-updates from `README.md` on each release. Edit `README.md` here, tag, release.

---

## Rollback

If a published version is broken:

1. **Don't delete the tag** — consumers may have pinned to it. Instead, mark the GitHub release as "pre-release" and publish a hotfix `v1.0.1`.
2. Move the floating `v1` tag back to the previous good release: `git tag -f v1 v1.0.0 && git push -f origin v1`. This unsticks consumers pinned to `@v1` without breaking those pinned to `@v1.0.x`.

---

## What's deliberately NOT in v1.0.0

The Action wraps `segspec analyze` and `segspec diff` only. The four other subcommands segspec gained in v0.6.0 — `snapshot`, `validate`, `coverage`, `explain` — are mentioned in the README's Roadmap section as future Action wrappers. For now, consumers can run them directly from the segspec binary in any subsequent step (it's on `$PATH`).
