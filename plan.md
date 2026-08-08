# Conductor — a self-hosted job runner platform

**A learning project for Kubernetes, ArgoCD, Prometheus, Grafana, and Alembic.**

Target: local `kind` cluster · beginner-friendly ordering · open-ended portfolio depth

---

## The idea

Build **Conductor**: a small platform where users submit background jobs over an HTTP API, workers pull them off a Postgres-backed queue, execute them, and report results. Think a tiny, honest version of Celery/Sidekiq — but the *point* is not the job runner. The point is the platform around it.

```
              ┌──────────┐
  client ───▶ │   API    │ ──┐
              │ (FastAPI)│   │
              └──────────┘   ▼
                        ┌─────────┐      ┌──────────┐
                        │ Postgres│ ◀─── │ Workers  │ (N replicas)
                        └─────────┘      └──────────┘
                             ▲
                        ┌────┴─────┐
                        │ Alembic  │ (migration Job)
                        └──────────┘
```

### Why this domain and not a CRUD app

A job queue is the rare toy app that generates *genuinely interesting telemetry for free*. You don't have to invent reasons to build a dashboard:

| Technology | What this app forces you to actually learn |
|---|---|
| **Kubernetes** | Two workload shapes (long-lived API vs. scalable workers), a stateful DB, one-shot Jobs, probes that mean something, HPA that has a real signal to scale on |
| **Alembic** | The queue table is the hottest table in the system. Every schema change is a change to a table under concurrent load — which is where the real migration lessons live |
| **ArgoCD** | Deploys must be *ordered* (migrate, then roll pods). That's sync waves and hooks, not just "argo applies YAML" |
| **Prometheus** | Queue depth, job latency, retry rate, worker saturation — four metric types (counter, gauge, histogram, summary) all have an obvious home here |
| **Grafana** | A queue has a natural SLO ("95% of jobs start within 30s") so alerting isn't academic |

The killer scenario you're building toward is **Milestone 12**: change the schema of the jobs table while 500 jobs/min flow through it, with zero errors, using only git commits. That single exercise touches all five technologies at once.

---

## Suggested repo layout

Keep app and infra in one repo at first — split later if you want to learn multi-repo GitOps.

```
conductor/
├── Makefile                  # make up / make down / make load
├── app/
│   ├── api/                  # FastAPI service
│   ├── worker/               # worker loop
│   ├── models/               # SQLAlchemy models
│   ├── alembic/versions/     # migrations
│   └── Dockerfile
├── k8s/
│   ├── base/                 # kustomize base
│   └── overlays/{dev,staging}/
├── platform/                 # argocd, kube-prometheus-stack, grafana dashboards
│   └── dashboards/*.json
├── argocd/                   # Application / ApplicationSet manifests
└── docs/runbooks/            # written from incidents you cause on purpose
```

---

# Milestones

Each milestone has a **done when** you can objectively check. Resist moving on until it's true.

## Phase 0 — Ground floor

### M0. One-command reproducible cluster
Set up `kind` with an ingress controller and a local image registry. Write a `Makefile` with `up`, `down`, `reset`.

**Learn:** kind config (port mappings, multi-node), why `kubectl` context matters, how images get into a kind cluster (`kind load` vs. local registry).

#### Tooling to install here

`kind`, `kubectl`, `helm`, and the `argocd` CLI are load-bearing — the milestones don't work without them. Two more are worth installing even though nothing strictly requires them, because most of what this project teaches is learned by *watching cluster state change*, and plain `kubectl` is a poor instrument for that:

| Tool | Why it earns its place |
|---|---|
| **k9s** | A live terminal UI over the cluster. `kubectl get pods` samples state at one instant; the lessons are in the *transitions* — `Pending → ContainerCreating → Running`, a rolling update replacing pods one at a time, `CrashLoopBackOff` backing off at increasing intervals. Polling with `kubectl get -w` makes you miss them. Pays for itself in M2 (delete a pod, watch it return), M3 (migration Job completes, *then* pods roll), M11 (2 → 10 replicas and back), and M13, where every drill is a state transition. |
| **stern** | Tails logs from many pods at once with color-coded prefixes, and picks up new pods as they appear. M2's own gate — *"scale workers to 5 and confirm no job is processed twice"* — is not checkable without reading five workers' logs interleaved. `kubectl logs` gives you one pod at a time. Same story in M11 (autoscaled pods arrive mid-tail) and M12 (old and new code both logging during a rolling update). |

> **Caveat from M4 onward:** k9s makes it a single keystroke to edit or delete a live resource. That violates the git-only rule below. Treat it as read-only once ArgoCD is in charge — use it to *watch*, never to *fix*.

> **Done when:** `make down && make up` gets you from nothing to a working cluster with ingress in under 3 minutes, and you've done it at least twice without editing anything by hand.

---

### M1. The app, no Kubernetes at all
FastAPI + Postgres via `docker compose`. One `jobs` table (`id, type, payload, status, attempts, created_at, started_at, finished_at`). Endpoints: submit, get status, list. A worker process that claims jobs with `SELECT ... FOR UPDATE SKIP LOCKED` and runs them.

Initialize Alembic here. Your first migration creates the table.

**Learn:** Alembic's `env.py`, autogenerate vs. hand-written migrations, `upgrade`/`downgrade`, why autogenerate misses things (indexes on expressions, server defaults, enum changes).

> **Done when:** you can submit a job, watch a worker pick it up, and run `alembic upgrade head` → `downgrade -1` → `upgrade head` cleanly three times in a row. Write a migration by hand (no autogenerate) at least once.

---

### M2. Deploy it by hand, with raw YAML
No Helm, no Kustomize, no Argo. Just `kubectl apply -f`. Postgres as a StatefulSet with a PVC. API as a Deployment behind a Service and Ingress. Workers as a separate Deployment. Config in a ConfigMap, DB password in a Secret.

**Learn:** the object model, labels/selectors, why Services find pods, readiness vs. liveness vs. startup probes, requests vs. limits, what actually happens during a rolling update.

> **Done when:** the app is reachable through ingress from your browser, **and** you can open every YAML file and explain what every single field does. Delete a pod and watch it come back. Scale workers to 5 and confirm no job is processed twice.

---

### M3. Migrations as a first-class Kubernetes citizen ⭐
This is the milestone most tutorials skip, and it's where the depth is. Move `alembic upgrade head` out of your app's entrypoint and into a Kubernetes `Job`.

**Learn:**
- Why running migrations in the app entrypoint is a bug (N replicas race each other)
- Postgres advisory locks as the safety net
- `Job` semantics: `backoffLimit`, `activeDeadlineSeconds`, `ttlSecondsAfterFinished`
- Init container vs. Job vs. hook — the tradeoffs
- How to make a rollout *wait* for the migration

> **Done when:** deploying a new image runs the migration Job first, app pods roll only after it succeeds, **and** a deliberately broken migration (e.g. `ALTER TABLE` referencing a nonexistent column) fails the Job and leaves the old app version running and healthy. Prove the second half — don't assume it.

---

## Phase 1 — GitOps

### M4. ArgoCD, and your first sync
Install ArgoCD. Convert your raw YAML to a Kustomize base. Create one `Application` pointing at `k8s/overlays/dev`. Turn on automated sync with prune and self-heal.

**Learn:** the reconciliation loop, desired vs. live state, what "OutOfSync" vs. "Degraded" actually mean, `kubectl` becoming read-only in your head.

> **Done when:** you `kubectl delete deployment api` and Argo restores it within seconds. Every change from here on goes through a git commit — make this a hard personal rule for the rest of the project.

---

### M5. Sync waves and the PreSync hook
Reattach M3's migration Job to Argo as a `PreSync` hook. Order Postgres → migration → API → workers with `argocd.argoproj.io/sync-wave`.

**Learn:** hook types (`PreSync`, `Sync`, `PostSync`, `SyncFail`), hook deletion policies, how waves interact with health checks, why a hook that never completes hangs your sync forever.

> **Done when:** a single commit that bumps the image tag *and* adds a migration deploys in the correct order, and a commit with a broken migration aborts the sync with the old version still serving traffic.

---

### M6. Multiple environments without copy-paste
Add a `staging` overlay (more replicas, real resource limits, different DB size). Manage both with an `ApplicationSet` and adopt the app-of-apps pattern so ArgoCD manages ArgoCD's own config.

**Learn:** Kustomize patches vs. Helm values, ApplicationSet generators (list, git directory), config drift between environments, why "it works in dev" happens.

> **Done when:** one commit to `base/` correctly propagates to both environments with their own values, and you have zero duplicated YAML between the overlays.

---

## Phase 2 — Observability

### M7. The Prometheus stack, GitOps-managed
Deploy `kube-prometheus-stack` (Helm chart) *through ArgoCD*, not by hand. Explore what comes free: kube-state-metrics, node-exporter, cAdvisor.

**Learn:** how Prometheus service discovery works in Kubernetes, the Operator's CRDs (`ServiceMonitor`, `PodMonitor`, `PrometheusRule`), scrape intervals and cardinality, why Prometheus is pull-based.

> **Done when:** you can answer these in the Prometheus UI with PromQL you wrote yourself: How much memory is each worker pod using? How many times has any pod restarted in the last hour? Which container is closest to its CPU limit?

---

### M8. Instrument your own app ⭐
Add `prometheus_client` to the API and workers. Deliberately use all the metric types:

- **Counter:** `jobs_submitted_total{type}`, `jobs_failed_total{type,reason}`
- **Histogram:** `job_duration_seconds{type}`, `http_request_duration_seconds{route,status}`
- **Gauge:** queue depth by status

Queue depth is the interesting trap: a gauge set per-replica gives you N conflicting answers. Solve it properly — a small dedicated exporter that queries Postgres, or `postgres_exporter` with a custom query.

**Learn:** metric naming conventions, label cardinality (never label with `job_id`), histogram buckets and why the defaults are wrong for you, `rate()` vs `increase()` vs `irate()`, why averages lie and `histogram_quantile` exists.

> **Done when:** your metrics appear in Prometheus via a `ServiceMonitor`, and you can write PromQL for: p95 job duration by type, error rate as a percentage of total, and current queue depth that doesn't multiply by replica count.

---

### M9. Grafana dashboards as code
Provision dashboards from JSON files in git via ConfigMaps, managed by Argo. No clicking-and-saving. Build three:

1. **API RED dashboard** — Rate, Errors, Duration
2. **Queue health** — depth over time, jobs/sec in vs. out, worker saturation, oldest pending job age
3. **Postgres** — connections, slow queries, table sizes, lock waits (you'll need this in M12)

**Learn:** dashboard variables and templating, repeated rows, why a dashboard you can't reproduce is a liability, the difference between a dashboard for debugging and one for monitoring.

> **Done when:** `make down && make up` rebuilds the entire cluster and all three dashboards return, identical, with no manual step.

---

### M10. SLOs and alerts that mean something
Define an SLO: *99% of jobs start within 30 seconds of submission.* Build recording rules for the SLI, then multi-window multi-burn-rate alerts on the error budget. Route Alertmanager to a local webhook receiver so you can see the payloads.

**Learn:** recording rules and why they exist (expensive queries, consistency), `for:` duration and alert flapping, burn-rate alerting vs. naive threshold alerting, alert labels → routing tree → receiver, inhibition and grouping.

> **Done when:** you scale workers to 0, and within a few minutes a real alert fires, routes correctly, and its annotation links to a runbook you wrote. Then scale back up and watch it resolve.

---

## Phase 3 — The advanced material

### M11. Autoscale workers on queue depth
Deploy `prometheus-adapter` and configure an HPA that scales the worker Deployment on your custom queue-depth metric — not CPU.

**Learn:** the custom metrics API, how the HPA controller computes desired replicas, stabilization windows and scaling policies, why scaling on CPU is wrong for queue consumers.

> **Done when:** dumping 500 jobs scales workers from 2 → 10, the queue drains, and workers scale back down without thrashing. Screenshot the Grafana panel showing all three curves (queue depth, replica count, throughput) telling one story.

---

### M12. Zero-downtime schema evolution under load ⭐⭐
**The centerpiece.** Rename `payload` → `input_data` on the jobs table while a load generator pushes continuous traffic, using the expand/contract pattern across three separate deploys:

1. **Expand** — add the new column, deploy code that writes both and reads old
2. **Backfill** — a Job that migrates existing rows in batches, then deploy code that reads new
3. **Contract** — deploy code that writes only new, then drop the old column

**Learn:** which DDL takes an `ACCESS EXCLUSIVE` lock and for how long, `lock_timeout` as a seatbelt, `CREATE INDEX CONCURRENTLY` (and why Alembic needs `autocommit_block()` for it), batched backfills vs. one giant `UPDATE`, and the core insight: *a migration must be compatible with both the old and new version of the code, because during a rolling update both are running.*

> **Done when:** your Grafana error-rate panel is flat across all three deploys under sustained load. Then do it again the naive way (one migration, rename in place) and capture the outage in Grafana. Save both screenshots side by side — that comparison is the whole project in one image.

---

### M13. Break it on purpose, write runbooks
Run failure drills and document each one in `docs/runbooks/` as you go:

- Delete the Postgres pod mid-job — what happens to in-flight work?
- Set a worker memory limit too low, get OOMKilled, watch the CrashLoopBackOff
- Ship a migration that takes a table lock for 60 seconds under load
- Roll back an ArgoCD Application to a previous git SHA
- Fill the PVC to 100%
- Deploy an image tag that doesn't exist

**Learn:** `kubectl describe` and `events` as your first stop, exit code 137, `pg_stat_activity` and `pg_locks`, why `imagePullBackOff` doesn't take down the running version, ArgoCD rollback vs. `git revert` (spoiler: prefer the revert).

> **Done when:** you have six runbooks written from incidents you actually caused, each with symptoms, diagnosis commands, and resolution.

---

### M14. Progressive delivery gated on metrics *(stretch)*
Replace the worker Deployment with an Argo Rollout doing a canary, with an `AnalysisTemplate` that queries Prometheus and auto-aborts if error rate exceeds threshold during the canary window.

> **Done when:** you deploy a deliberately broken version and the rollout aborts itself and reverts — without you touching anything.

---

## How to work through this

**Commit discipline:** From M4 onward, if you fixed something with `kubectl edit`, you haven't fixed it. Undo it and do it in git.

**Keep an engineering log.** One markdown file, dated entries, one paragraph per session: what you tried, what broke, what the actual cause was. This will be more valuable to you in six months than the code, and it's what makes the project legible to someone else.

**When you get stuck for more than an hour**, that's a signal you're missing a mental model, not a config flag. Stop and go read the concept page for whatever component is confusing you. The docs for all five of these tools are unusually good.

**Realistic pacing at evening speed:** Phase 0 ≈ 2 weeks · Phase 1 ≈ 2 weeks · Phase 2 ≈ 3 weeks · Phase 3 ≈ 3+ weeks. M12 alone is worth a full week — don't rush it, it's the milestone that makes the project distinctive.

---

## Traps worth walking into deliberately

These teach more than reading about them ever will:

- Run migrations from the app entrypoint with 3 replicas. Watch the race.
- Label a metric with `job_id`. Watch Prometheus memory climb.
- Put the DB password in a ConfigMap. Then discover it's base64, not encryption, in a Secret too — and go look at Sealed Secrets or External Secrets.
- Set `imagePullPolicy: Always` with tag `latest` and try to figure out which version is running.
- Forget `ttlSecondsAfterFinished` and accumulate 200 completed migration Jobs.
- Write an alert without a `for:` clause and get paged by a 15-second blip.