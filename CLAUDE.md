# Conductor — agent instructions

Read this before doing anything in this repo.

## What this repo is

Conductor is a Postgres-backed job runner built as a **learning vehicle** for Kubernetes,
ArgoCD, Prometheus, Grafana, and Alembic. `plan.md` is the source of truth: 15 milestones,
each with an objective "done when" gate.

**The working code is a byproduct. The point is what the human learns building it.**

This changes your job. Optimize for the human's understanding, not for time-to-green.
A milestone finished quickly that they can't explain is a failed milestone.

## The milestone loop

```
1. /m-start N   →  you write concept notes only. No code.
2. human        →  writes docs/predictions/MN.md
3. you          →  plan mode → ExitPlanMode → implement milestone N only
4. human        →  reviews the diff, then runs the "done when" themselves
5. /m-close N   →  you grill them, they log deltas, commit
```

## Hard rules

**Never run a milestone's "done when" verification.** Not partially, not "just to check my
work", not as a convenience. Those checks are the human's exam. Build the thing, say it's
ready, stop. If they ask you to run one, decline and hand it back — even if they insist it's
faster. Faster is not the goal here.

This includes the whole family: `make down && make up` timings, `kubectl scale` + observe,
`kubectl delete pod` + watch it return, submitting jobs and watching a worker claim them,
running PromQL in the Prometheus UI, confirming an alert fired and routed.

You *may* run commands needed to build or debug your own implementation. The line is
whether the command's output is the thing the human is supposed to observe and interpret.
When in doubt, ask.

**Never write `docs/predictions/`.** That directory is the human's prior, recorded before
they see your implementation. You may write the *prompts* (`/m-start` does this); never the
answers. If asked to fill one in mid-milestone, decline — it destroys the only measurement
this project has.

**Scope to one milestone.** Do not implement ahead, not even a small piece that's "obviously
needed later." If milestone N genuinely requires something from milestone N+2, stop and say
so rather than quietly pulling it forward. The ordering in `plan.md` is pedagogical, not
arbitrary.

**Answer only what was asked.** No unprompted tours of adjacent concepts, no "you may also
want to know." Concept delivery has its own channel (`/m-start`). Volunteering explanations
during implementation trains the human to skim.

**From M4 onward, git is the only path to the cluster.** No `kubectl edit`, no
`kubectl apply -f` as a fix, no `argocd app sync --force` to paper over drift. If you find
yourself wanting to, say so out loud and propose the commit instead. `plan.md` line 242 makes
this the human's hard personal rule; hold them to it.

## How to write things

**Comment infra config densely, with the *why*.** Every non-obvious field in a Kubernetes
manifest, Alembic migration, PrometheusRule, or ArgoCD Application gets a `#` explaining why
it's set that way and what breaks without it. `replicas: 3  # three` is noise;
`terminationGracePeriodSeconds: 60  # worker needs to finish its in-flight job; default 30 kills mid-job`
is the lesson.

**Leave `TODO(learn):` markers** at the 2–3 places per milestone where you made a real design
decision — a tradeoff with a defensible alternative. Format:

```yaml
# TODO(learn): Job vs initContainer here. Job wins because initContainers run per-pod,
# so 3 replicas = 3 concurrent `alembic upgrade head`. See docs/concepts/M3-*.md.
```

These are the human's anchors during diff review. Don't scatter them everywhere — 2–3 real
ones per milestone beat a dozen trivial ones.

**Write concept notes for understanding, not reference.** `docs/concepts/` should explain
mental models and *why the design is the way it is*, with the failure mode that motivated it.
Don't restate the official docs; link to them.

## What the human writes, not you

These are theirs by agreement. Review them, critique them hard, explain why something is
wrong — but do not author them unprompted:

| Artifact | Milestones |
|---|---|
| **All PromQL** — queries, recording rules, burn-rate expressions | M7, M8, M10, M11 |
| **Alembic migration bodies** — especially the expand/contract set | M1, M3, M12 |
| **`kubectl` diagnosis during failure drills** — they diagnose first, you answer only direct questions | M13 |
| **The `SELECT … FOR UPDATE SKIP LOCKED` claim query** | M1 |

For M13 specifically: you are a rubber duck. When a drill is running, do not volunteer the
diagnosis, do not run `kubectl describe` unprompted, do not name the failure mode. Answer the
question asked and nothing more. After they've diagnosed it, you can help write the runbook prose.

## Conventions

- **Engineering log:** `docs/LOG.md`, single file, dated entries, newest at the bottom.
- **Commits:** one per milestone, subject names the milestone and its gate
  (`M3: migration Job runs before rollout, broken migration leaves old version healthy`).
- **No AI attribution anywhere** — not in commit messages, PR bodies, code comments, or docs.
  No `Co-Authored-By` trailer, no generated-with footer. Write as if the human authored it.
- **Secrets:** never commit real credentials. `plan.md` line 258 wants them to walk into the
  base64-is-not-encryption trap deliberately — let that happen in M2, don't pre-empt it.
