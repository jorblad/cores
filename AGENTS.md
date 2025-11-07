# Repository Guidelines

## Project Structure & Module Organization
- `docker-compose.yml` orchestrates RentalCore, WarehouseCore, MySQL, and Mosquitto; keep service names aligned with upstream app repos.
- `rentalcore/` (Go 1.23) handles job and customer flows; key paths are `cmd/server`, `internal/`, `web/`, and migrations.
- `warehousecore/` (Go 1.24) mirrors the layout for warehouse features; shared validators live in `internal/validation`.
- Root `migrations/` and `RentalCore.sql` feed MySQL; update when schema changes span services.
- Deployment examples in `nginx-reverse-proxy.conf`, `docker-compose.*.yml`, and `docs/` must mirror port, domain, or env changes.
- Ensure both cores stay fully deployable and feature-complete with one `docker-compose.yml` plus `.env` on any host.

## Build, Test & Development Commands
- **Never** start the stack locally on this server. The managed environment already runs on `docker03.nt.local` (user `noah`, SSH key installed). You may SSH there to inspect logs, configuration, and version details, but must not apply any changes or manage container lifecycle actions—those (start/stop/redeploy) remain strictly manual by Noah.
- `docker compose up -d` — start the full stack locally.
- `docker compose logs -f rentalcore|warehousecore` — stream logs.
- `docker compose down -v` — reset containers and volumes for clean-state verification.
- `make build`, `make run`, `make dev-setup` inside `rentalcore/` — compile, run, or bootstrap dependencies.
- `make build`, `make test`, `go test ./...` inside `warehousecore/` — build and test.
- Before releases, build and push each image with the next sequential version tag plus `latest` (e.g., `docker build -t nobentie/rentalcore:1.2.0 -t nobentie/rentalcore:latest . && docker push ...`).

## Coding Style & Naming Conventions
- Run `gofmt` (or `go fmt ./...`) before review; apply `goimports` when imports change.
- Keep `internal/` packages scoped by domain (`jobs`, `validation`, `mqtt`) and avoid cross-package coupling.
- Follow identifier patterns: PascalCase for exports, camelCase for locals, uppercase snake case for config keys.
- Static assets in `web/` use kebab-case filenames and established folder splits (`css/`, `js/`, `img/`).

## Testing Guidelines
- Mirror the source tree with package-level `_test.go` files and favor table-driven cases.
- Run `go test ./...` from each service root before pushing; add coverage whenever touching `internal` logic or SQL migrations.
- For database-impacting changes, refresh root migrations and validate with `docker compose up` against a clean volume.

## Deployment Discipline
- For every change, always build and push the matching Docker image to Docker Hub after checking the latest published tag.
- Mirror the build by pushing code to GitLab (per-service repo + cores if affected) so image and source stay in sync.
- Before starting a build, check Docker Hub for the most recent `nobentie/rentalcore` tag and bump to the next sequential version, then push both the new tag and `latest` alongside the corresponding GitLab commit.

## Commit & Pull Request Guidelines
- Use imperative, present-tense commit subjects (e.g., `Ensure default admin seeding matches new RBAC`) capped at 72 characters.
- Group related work per service; cross-cutting updates should call out both modules and referenced schema changes in the body.
- PRs must describe the scenario, list test commands, link issues, and include UI screenshots when `web/` assets change.
- Highlight secrets or domain changes for release notes and request review from both service owners on shared infrastructure updates.
