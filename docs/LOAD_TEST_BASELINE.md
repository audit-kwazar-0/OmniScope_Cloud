# Load Test Baseline

## Purpose

This document tracks the reference performance profile used for regression checks in CI.

Source files:
- k6 script: `tests/load/k6-omniscope.js`
- baseline thresholds: `tests/load/baseline.json`
- runner: `scripts/run-load-test.sh`
- CI workflow: `.github/workflows/load-test.yml`

## Current baseline

- `p95_ms`: 300
- `error_rate`: 0.02

These values are used as initial guardrails and should be updated after stable validated runs in the target environment.

## Update process

1. Run at least 3 stable load tests in the same environment profile.
2. Verify no incident/noisy alert side effects.
3. Choose a realistic baseline from median run.
4. Update `tests/load/baseline.json`.
5. Document changes in PR notes and include summary JSON artifacts.

## Artifact interpretation

From `k6-summary-*.json`, focus on:
- `metrics.http_req_duration.values["p(95)"]`
- `metrics.http_req_duration.values["p(99)"]`
- `metrics.http_req_failed.values.rate`
- `metrics.http_reqs.values.rate`

## Suggested operating policy

- Allow up to `10%` p95 regression for non-production test clusters.
- For production-like environments, tighten to `5%`.
- Always fail on threshold breach for error rate.
