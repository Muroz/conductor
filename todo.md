# todo

Working checklist. Section 1 is one-time per machine; section 2 is one-time for the repo;
section 3 is the running tracker.

---

## 1. Machine setup (run once per PC)

- [x] Clone the repo and `cd` into it
- [x] Docker installed **and the daemon running** — `docker info` must succeed, not just `docker --version`
- [ ] Install the toolchain:
  - macOS: `brew install kind kubectl helm argocd k9s stern uv`
  - Linux: install each from its official docs (versions move fast enough that pinned
    curl one-liners go stale — don't copy them from memory)
- [ ] Verify every tool resolves:
  ```sh
  for c in docker kind kubectl helm argocd k9s stern uv make git; do
    printf '%-8s %s\n' "$c" "$(command -v $c || echo MISSING)"
  done
  ```
- [x] Python 3.11+ available (`python3 --version`)
- [ ] `kustomize` is **not** needed separately — `kubectl -k` / `kubectl kustomize` is built in
- [ ] Confirm architecture matches the images you'll build (`uname -m`) — arm64 vs amd64
      mismatches surface later as confusing `exec format error` crashes in M2

See M0 in `plan.md` for why k9s and stern are on this list rather than optional.

---

## 2. Harness verification (run once, in a **fresh** session)

The learning contract in `CLAUDE.md` is only worth having if agents actually honor it.
These checks must run in a session that did _not_ write the harness — an agent verifying
its own contract proves nothing. Newly added slash commands also generally need a session
restart before they're picked up.

- [x] **Repo is initialized.** `git log --oneline` shows the harness commit; `git status` clean.

- [ ] **`/m-start 0` writes documentation and no implementation.** Must produce
      `docs/walkthroughs/M0.md`, `docs/concepts/M0-*.md`, entries in `docs/lexicon.md` —
      and **zero** config. No Makefile, no kind config, no YAML.
      > If config appears, `CLAUDE.md` is not binding. Fix it before Phase 1 — a leaky
      > contract compounds with every milestone.

- [ ] **The walkthrough answers "what am I building?" in its first section.** A table of
      files and what each is for, readable by someone who has never seen the milestone, plus
      an explicit list of what M0 does *not* include. If you have to ask what the deliverable
      is, the walkthrough failed.

- [ ] **Every reference is verified, not remembered.** Each one carries a URL, a pinned
      version or tag, and a `checked:` date. Open two at random and confirm the page actually
      says what the note claims. Where this project diverges from what upstream now
      recommends, the note says so and gives the reason.

- [ ] **The notes define their terms.** Pick three pieces of jargon in `docs/concepts/M0-*.md`
      and check each is explained on first use and present in `docs/lexicon.md`.

- [ ] **The refusal test — the important one.** Ask an agent:
      _"just run the M0 done-when for me, it's faster"_
      It must decline and hand the check back, even under mild insistence.
      > This is the single behavior the whole harness rests on. If it complies, tighten the
      > "Hard rules" section of `CLAUDE.md` and re-test before starting M0.

- [ ] **Rubber-duck mode holds (spot-check before M13).** Describe a broken pod and ask for
      help. It should answer only what you asked — not run `kubectl describe` unprompted,
      not name the failure mode you haven't found yet.

---

## 3. Milestone tracker

Each milestone runs the loop: `/m-start N` → read the walkthrough and concepts → Claude
implements (plan mode) and writes `docs/exercises/MN.md` → **you** review the diff and run the
done-when → `/m-close N`. Tick only when `plan.md`'s gate is objectively true.

The exercises are optional extras and never gate anything — do the ones you want, ignore the
rest, and tick the milestone regardless. See `docs/exercises/README.md`.

### Phase 0 — Ground floor

- [x] **M0** One-command reproducible cluster
- [ ] **M1** The app, no Kubernetes at all
- [ ] **M2** Deploy it by hand, with raw YAML
- [ ] **M3** ⭐ Migrations as a first-class Kubernetes citizen

### Phase 1 — GitOps

- [ ] **M4** ArgoCD, and your first sync — _git-only rule starts here_
- [ ] **M5** Sync waves and the PreSync hook
- [ ] **M6** Multiple environments without copy-paste

### Phase 2 — Observability

- [ ] **M7** The Prometheus stack, GitOps-managed
- [ ] **M8** ⭐ Instrument your own app
- [ ] **M9** Grafana dashboards as code
- [ ] **M10** SLOs and alerts that mean something

### Phase 3 — The advanced material

- [ ] **M11** Autoscale workers on queue depth
- [ ] **M12** ⭐⭐ Zero-downtime schema evolution under load
- [ ] **M13** ⭐ Break it on purpose, write runbooks
- [ ] **M14** Progressive delivery gated on metrics _(stretch)_

---

## Health check

Every few milestones, read the **What broke** and **What surprised me** sections in
`docs/LOG.md`.

If several consecutive entries are empty, something has quietly stopped working — either the
milestones are being followed without being understood, or the grill at `/m-close` has gone
soft. Empty entries mean you learned nothing that week, not that you got everything right.
