# Engineering log

One entry per working session, dated, newest at the bottom. Written at `/m-close`.

**What broke** and **What surprised me** are the point of this file. A run of entries with
nothing in them means the milestones are being followed without being understood — that's a
signal to fix, not a clean record.

Entry format:

```markdown
## YYYY-MM-DD — MN: <milestone title>

**Built:** …

**What broke, and what actually caused it:** …

**What surprised me:** …

**Worth remembering:** …
```

---

## 2026-08-13 — M0: One-command reproducible cluster

**Built:** `make up` creates a three-node kind cluster (one control-plane, two workers) pinned
to `kindest/node:v1.35.5` by digest, starts a `registry:3` container on `127.0.0.1:5001` and
teaches each node's containerd to resolve `localhost:5001` to it, then applies a vendored
ingress-nginx `controller-v1.15.1` manifest and waits until ingress is actually usable.
`make down` deletes the cluster and keeps the registry; `make reset` takes both.
Host ports 80/443 map into the control-plane node only, bound to loopback.

**What broke, and what actually caused it:**

- `make up` failed on the gate run at `kubectl wait --for=condition=complete job/...` with
  NotFound for both `ingress-nginx-admission-create` and `-patch`. Cause: both Jobs carry
  `ttlSecondsAfterFinished: 0`, so the TTL-after-finished controller deletes them cascadingly
  the moment they complete — before the preceding `rollout status` wait had even returned. The
  wait was written against objects designed to delete themselves. Fixed by waiting on what the
  `-patch` Job *produces* instead: `--for=jsonpath='{.webhooks[0].clientConfig.caBundle}'` on
  the ValidatingWebhookConfiguration, which the vendored manifest ships without.
- `make down` then died with `Makefile:136: *** missing separator`. Cause: a block of prose had
  been pasted into the Makefile below the `load` target. Make hit text where it wanted a rule.
- Gate check 3 returned a 503 on `/foo` while `/bar` returned 200 from the same controller at
  the same moment. Cause: `foo-app` had no ready endpoints yet — the pod was still pulling
  `agnhost` on whichever node it landed on, and each node pulls independently. Not a
  configuration fault; it passed on retry.

**What surprised me:**

- `hostPort` is a scheduling constraint, not just a networking field. Setting `replicas: 2` on
  the ingress controller does not give redundancy — the second pod stays `Pending` forever,
  rejected by the scheduler's `NodePorts` filter with "node(s) didn't have free ports for the
  requested pod ports". So this ingress setup cannot be made redundant by scaling. That's the
  price of hostPort, and it's what a real cluster solves with a load balancer in front.
- Deleting a pod does not require re-applying its manifest. The ReplicaSet controller observes
  the difference between desired and actual and recreates it. I had the model wrong; that loop
  is the thing M4 builds on.
- 503 and 404 both mean nginx answered. Connection refused means nothing accepted the TCP
  connection at all. Three symptoms, three different layers, and I had been treating them as
  interchangeable failures.
- With `:latest`, the mutable tag is the actual damage; `imagePullPolicy` only selects which
  failure you get. `Always` breaks `kind load` outright; `IfNotPresent` silently leaves
  different nodes running different code under one tag.
- `listenAddress: "127.0.0.1"` versus the `0.0.0.0` default is invisible from the machine you
  test on. `curl localhost` is identical either way; only the port column in `docker ps` tells
  you whether the cluster is on the LAN.

**Worth remembering:**

- `kubectl wait --for=jsonpath='{...}'` with no `=value` waits for the field to become
  non-empty. Useful whenever the thing you care about is a field some controller fills in.
- `kubectl get endpoints <service>` — empty `ENDPOINTS` is the entire diagnosis for a 503.
- `kubectl get pods -o wide` — the `NODE` column is the first thing to check when something is
  `Running` and unreachable.
- Version skew: kubelet may be up to three minors behind kube-apiserver and **must not be
  newer**; kubectl is supported within one minor either way. Docker Desktop's kubectl in
  `/usr/local/bin` beats Homebrew's on PATH, which is why the node image is pinned to v1.35.5.
- Make conditionals (`ifndef`) are evaluated when the file is read, not when the target runs —
  a guard inside a recipe has to be a shell `test`.
- `docker network connect` errors if already connected; with `set -e` that aborts the script,
  which is why the registry step is guarded.
- `make reset` before timing `make up`, or you are measuring a warm cache.
- Timings: first cold `up` 1:25, second 1:11. Gate is 3:00.
