# Contributing to OmniScope Cloud

Thank you for taking the time to improve this repository. This document explains how we work together and what we expect from contributions.

---

## Table of contents

1. [Code of conduct](#code-of-conduct)
2. [How to contribute](#how-to-contribute)
3. [Branching & pull requests](#branching--pull-requests)
4. [Commit messages](#commit-messages)
5. [Project areas](#project-areas)
6. [Security & secrets](#security--secrets)
7. [Licensing](#licensing)

---

## Code of conduct

- Be respectful and constructive in reviews and discussions.
- Assume good intent; disagree on technical merits, not personalities.
- Keep feedback specific and actionable.

---

## How to contribute

1. **Fork** the repository (or use a branch on the org repo, if you have access).
2. **Create a branch** from `main` with a short, descriptive name (e.g. `fix/bicep-aks-output`, `docs/readme-examples`).
3. **Make focused changes** — one logical concern per pull request when possible.
4. **Test what you can** locally:
   - **Examples:** build images, push to ACR, apply `examples/kubernetes/` (see [`examples/README.md`](./examples/README.md)).
   - **Pulumi:** `cd infra/pulumi && npm ci && npm run build`.
   - **Bicep:** `az bicep build --file infra/bicep/main.bicep` (when Azure CLI is available).
   - **Terraform:** `terraform fmt` and `terraform validate` inside the relevant module directory.
5. **Open a pull request** with a clear title and description (what changed, why, and any follow-ups).

---

## Branching & pull requests

| Guideline | Detail |
|-----------|--------|
| **Base branch** | `main` unless agreed otherwise. |
| **PR size** | Prefer smaller PRs; large refactors should be discussed first. |
| **Description** | Summarize motivation, approach, and testing. Link issues if applicable. |
| **Docs** | If behavior or layout changes, update the relevant `README.md` or `doc-site/` content. |

Maintainers may request changes, squash commits, or adjust commit messages to keep history readable.

---

## Commit messages

Use clear, imperative summaries in English, for example:

- `Add Action Group output to Bicep module`
- `Fix Pulumi import paths for azure-native`
- `Document local OTel ports in examples README`

Optional body: explain *why* if the title is not enough.

---

## Project areas

| Path | Purpose |
|------|---------|
| [`doc-site/`](./doc-site/) | Architecture & workshop narrative (VitePress sources). Root **README.md** is mirrored into `doc-site/wiki/repository-readme.md` by `npm run sync-readme` (runs automatically before `docs:dev` / `docs:build`). |
| [`infra/`](./infra/) | Parallel IaC: Bicep, Terraform, Pulumi. Bicep: `infra/bicep/deploy.sh` (validate / what-if / deploy) and VS Code tasks **Bicep: …**. |
| [`examples/`](./examples/) | Go sample services + Kubernetes manifests for AKS; ACR / pipeline notes in `examples/docs/`. |

When adding infrastructure, keep the three stacks conceptually aligned where it makes sense (same resource names and parameters), or document intentional differences in the PR.

---

## Security & secrets

**Never commit:**

- Azure subscription IDs, tenant IDs, client secrets, or SAS tokens.
- Personal access tokens, SSH private keys, or `.env` files with real credentials.
- Production connection strings or API keys.

Use placeholders in documentation (e.g. `oncall@example.com`). If you discover a leaked secret in git history, rotate the credential immediately and notify maintainers.

---

## Licensing

By contributing, you agree that your contributions are licensed under the same terms as the project — see [`LICENSE`](./LICENSE) (MIT).

---

Questions? Open a discussion or issue on GitHub. Thank you again for helping make OmniScope Cloud better.
