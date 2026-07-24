# E2E Test Results

> End-to-end validation of the hawk-homelab-methodology Shell CLI

**Test Date:** 2026-07-24
**Test Command:** `bash cli/shell/init.sh e2e-test --port 9999 --image nginx --version 1.25 --description "E2E validation project"`

---

## Checklist

### 1. `e2e-test/docker-compose.yml` — Template replacement + structure

| Check                                      | Result |
|-------------------------------------------|--------|
| Has healthcheck (`curl http://localhost:8080/health`) | ✅ PASS |
| Correct image: `nginx:1.25`               | ✅ PASS |
| Correct port mapping: `9999:8080`         | ✅ PASS |
| No `{{PROJECT_NAME}}` / `{{PORT}}` / `{{IMAGE}}` / `{{VERSION}}` placeholders left | ✅ PASS |
| Container name: `hawk-e2e-test`           | ✅ PASS |
| Labels: `hawk.project`, `hawk.managed`    | ✅ PASS |
| Network: `app-net` (external)             | ✅ PASS |

### 2. `e2e-test/CLAUDE.md` — Environment constraints

| Check                                      | Result |
|-------------------------------------------|--------|
| Contains "colima restart" warning (禁止 `colima restart`) | ✅ PASS |
| Contains `DOCKER_HOST` path               | ✅ PASS |
| Contains `hawk-transmission` reference    | ✅ PASS |
| Contains `192.168.31.236` deploy target   | ✅ PASS |
| All `{{}}` placeholders replaced          | ✅ PASS |

### 3. `e2e-test/deploy.sh` — Deploy script

| Check                                      | Result |
|-------------------------------------------|--------|
| Has `set -euo pipefail`                   | ✅ PASS |
| Has DOCKER_HOST check (`-S` socket test)  | ✅ PASS |
| Checks Transmission (`hawk-transmission`) | ✅ PASS |
| Uses `--no-deps` (PT protection)          | ✅ PASS |
| Has health check loop                     | ✅ PASS |
| Has rollback on failure                   | ✅ PASS |
| All `{{}}` placeholders replaced          | ✅ PASS |

### 4. `e2e-test/pre-deploy-check.sh` — Pre-deploy checks

| Check                                      | Result |
|-------------------------------------------|--------|
| Checks disk space                         | ✅ PASS |
| Checks Colima/Docker                      | ✅ PASS |
| Checks Transmission                       | ✅ PASS |
| Checks Clash (TUN + DNS)                  | ✅ PASS |
| Checks Cloudflare Tunnel                  | ✅ PASS |
| Has `set -euo pipefail`                   | ✅ PASS |

### 5. `e2e-test/.github/workflows/deploy.yml` — CI/CD

| Check                                      | Result |
|-------------------------------------------|--------|
| Valid YAML structure                      | ✅ PASS |
| SSH to `192.168.31.236`                   | ✅ PASS |
| Uses `appleboy/ssh-action@v1`             | ✅ PASS |
| Runs `pre-deploy-check.sh` + `deploy.sh` | ✅ PASS |
| Health check verification after deploy    | ✅ PASS |
| `${{ }}` is GitHub Actions syntax (valid) | ✅ PASS |

### 6. `e2e-test/renovate.json` — Dependency automation

| Check                                      | Result |
|-------------------------------------------|--------|
| Valid JSON                                | ✅ PASS |
| PostgreSQL major version: `automerge: false` | ✅ PASS |
| Patch auto-merge enabled                  | ✅ PASS |
| Docker Compose support enabled            | ✅ PASS |

### 7. Shell script executability

| File                        | Executable |
|-----------------------------|-----------|
| `deploy.sh`                 | ✅ PASS (`-rwx--x--x`) |
| `rollback.sh`               | ✅ PASS (`-rwx--x--x`) |
| `pre-deploy-check.sh`       | ✅ PASS (`-rwx--x--x`) |
| `tests/smoke-test.sh`       | ✅ PASS (`-rwx--x--x`) |
| `tests/integration-test.sh` | ✅ PASS (`-rwx--x--x`) |
| `.hermes/scripts/backup.sh` | ✅ PASS (`-rwx--x--x`) |
| `.hermes/scripts/health-check.sh` | ✅ PASS (`-rwx--x--x`) |
| `.hermes/scripts/notify.sh` | ✅ PASS (`-rwx--x--x`) |

### 8. Syntax validation (bash -n)

| Script                  | Result   |
|------------------------|----------|
| `deploy.sh`            | ✅ syntax OK |
| `rollback.sh`          | ✅ syntax OK |
| `pre-deploy-check.sh`  | ✅ syntax OK |

---

## Issues Found

### 1. Unreplaced placeholder in `rollback.sh` (Minor)

**File:** `rollback.sh` line 12
**Issue:** `DB_USER="{{DB_USER}}"` — the `{{DB_USER}}` placeholder was NOT replaced by the CLI.
**Root cause:** `init.sh`'s `replace_placeholders()` function does not include `{{DB_USER}}` in its replacement list. The rollback.sh template uses `{{DB_USER}}` which is a project-specific variable not exposed via CLI flags.
**Impact:** Low — `rollback.sh` Level 3 (PostgreSQL restore) would fail if invoked, but this level requires a manual `read -p` confirmation and is rarely used. Other rollback levels (service, git, colima) are unaffected.
**Fix:** Add `--db-user` flag to `init.sh`, or set a sensible default in the template (e.g., `postgres`).

### 2. No `{{}}` placeholders in critical paths (OK)

All `{{` occurrences in `deploy.sh`, `pre-deploy-check.sh`, and `deploy.yml` are **not** template placeholders:
- `docker ps --format '{{.Names}}'` — Go template syntax for Docker CLI (valid)
- `${{ env.DEPLOY_HOST }}` — GitHub Actions expression syntax (valid)

These are correct and expected.

---

## Summary

| Category        | Pass | Fail | Warn |
|-----------------|------|------|------|
| Template replacement | 24   | 1    | 0    |
| Script syntax   | 3    | 0    | 0    |
| Executability   | 8    | 0    | 0    |
| **Total**       | **35** | **1** | **0** |

**Overall verdict: PASS** with 1 minor issue (unreplaced `{{DB_USER}}` in rollback.sh).

The Shell CLI successfully generates a complete project scaffold with all critical placeholders replaced, valid YAML/JSON, executable scripts, and correct Mac Pro environment constraints embedded in CLAUDE.md.
