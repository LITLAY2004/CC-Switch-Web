CC-Switch Web API Bash Test Suite
=================================

This suite exercises the Axum web server REST API (Basic Auth protected) via bash + curl. It focuses on provider management, usage scripts, settings, MCP servers, and end-to-end workflows for the web server mode.

Prerequisites
-------------
- Running CC-Switch web server with `web-server` feature enabled.
- Basic Auth credentials: username `admin`, password from `~/.cc-switch/web_password` (or env).
- Tools: `bash`, `curl`, `jq`.
- Network access to `https://postman-echo.com` (override by editing `helpers/test-data.json` if offline).

Environment knobs
-----------------
- `HOST` / `PORT` / `SCHEME` / `API_PREFIX` / `API_BASE`: target server (defaults to `http://localhost:8080/api`).
- `USERNAME` / `PASSWORD` / `PASSWORD_FILE`: Basic Auth (password defaults to `~/.cc-switch/web_password`, then `test`).
- `REQUEST_TIMEOUT`: curl timeout in seconds (default 15).
- `CURL_FLAGS`: extra curl flags (e.g., `--insecure` for self-signed certs).
- `TEST_DATA_FILE`: alternate fixture path (default `tests/helpers/test-data.json`).

Layout
------
- `helpers/common.sh` – shared curl wrappers, assertions, color output, config backup/restore helpers.
- `helpers/test-data.json` – provider/MCP/settings fixtures and usage scripts.
- `api/test-auth.sh` – Basic Auth coverage.
- `api/test-providers.sh` – provider CRUD + switch.
- `api/test-usage.sh` – saved usage queries and `/usage/test` for PackyCode / 88code / Privnode.
- `api/test-settings.sh` – read/write `AppSettings`.
- `api/test-mcp.sh` – MCP server CRUD.
- `integration/test-full-workflow.sh` – add→switch→verify→update→delete provider flow.
- `integration/test-persistence.sh` – export/import persistence guard.
- `run-all.sh` – orchestrates all bash tests (accepts optional script list).

Running tests
-------------
Run everything:
```
cd /root/cc-switch
bash tests/run-all.sh
```

Run a single test:
```
cd /root/cc-switch
bash tests/api/test-providers.sh
```

Notes and side effects
----------------------
- Each API/integration script exports the current config (`/api/config/export`) and restores it on exit to avoid polluting real data, but switching providers may briefly write to `~/.codex`, `~/.claude`, or `~/.gemini`. Run in an isolated profile if you want zero risk to personal configs.
- Usage tests call `postman-echo.com`; update `helpers/test-data.json` (`usageScripts.baseUrl`) if you need an internal echo endpoint.
- Test output shows ✓/✗ per assertion plus a summary with a non-zero exit code on failure.

Adding new tests
----------------
1. Place new scripts under `tests/api` or `tests/integration` and source `helpers/common.sh`.
2. Use `read_fixture` to pull data from `helpers/test-data.json` instead of hardcoding secrets.
3. Wrap stateful flows with `backup_config`/`restore_config` to keep environments clean.
4. Add the script path to `tests/run-all.sh` to include it in the suite.

CI/CD suggestions
-----------------
- Start the web server in test mode before running `tests/run-all.sh`.
- Fail the pipeline on any non-zero exit.
- Cache `node_modules`/Rust deps separately; these bash tests only depend on curl+jq.
- Collect logs from the web server to diagnose failed HTTP interactions.
