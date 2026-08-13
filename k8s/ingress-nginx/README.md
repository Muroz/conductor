# ingress-nginx, vendored

`deploy-v1.15.1.yaml` is a copy of an upstream manifest with exactly one local change. This
file records where it came from and what we changed, so the next person can redo it without
guessing.

## Where it came from

```sh
curl -fsSL -o k8s/ingress-nginx/deploy-v1.15.1.yaml \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
```

| | |
|---|---|
| Tag | `controller-v1.15.1`, released 2026-03-19 |
| Vendored | 2026-08-11 |
| Upstream length | 679 lines, 19 objects |
| Upstream sha256 | `2a3ae008c8786431115502644e77ab398fdebfb721a5d1195ed3089cde3299df` |
| Controller image | `registry.k8s.io/ingress-nginx/controller:v1.15.1@sha256:594ceea76b01c592858f803f9ff4d2cb40542cae2060410b2c95f75907d659e1` (pinned by digest upstream) |

Keep that sha256. Re-download the same tag, compare, and you know whether the file drifted or
someone hand-edited it.

**Why vendored instead of `kubectl apply -f <url>`.** `make up` then needs no network for this
step, and the version cannot change under us. The cost is a 700-line file in the diff of this
milestone — you are not expected to read all of it.

## What we changed

One thing. The controller Deployment's `nodeSelector` gains a second key:

```yaml
      nodeSelector:
        kubernetes.io/os: linux
        ingress-ready: "true"     # <- added
```

plus a comment above it and a provenance header at the top of the file. Nothing else. The
`diff` against the upstream file is that block and the header, and nothing more.

## Why we add back a selector upstream deleted

This manifest used to carry `ingress-ready: "true"` itself. That is why every kind tutorial
tells you to label a node `ingress-ready=true`. It was removed. Checked on 2026-08-11 by
fetching `deploy/static/provider/kind/deploy.yaml` at four tags:

| Tag | `ingress-ready` present? |
|---|---|
| `controller-v1.11.5` | yes |
| `controller-v1.12.0` | yes |
| `controller-v1.13.9` | **no** |
| `controller-v1.14.5` | no |
| `controller-v1.15.1` | no |

What it has instead is `nodeSelector: kubernetes.io/os: linux` and a *toleration* for the
control-plane taint. A toleration permits scheduling on a control-plane node; it does not
require it.

On a single-node kind cluster that distinction never surfaces — there is one node, the pod
goes there, the manifest works unmodified. Our cluster has three nodes and only the
control-plane node has host ports 80 and 443 mapped in (`kind/cluster.yaml`). If the scheduler
picks a worker, `kubectl get pods` says `Running`, the controller logs look healthy, and
`curl http://localhost/` gets connection refused. Nothing is broken as far as Kubernetes is
concerned, so nothing reports an error.

So the label lives in `kind/cluster.yaml` and the selector lives here. **The two files have to
agree.** That coupling is the price of the three-node cluster; see the `TODO(learn):` in
`kind/cluster.yaml` for the single-node alternative.

Reasoning in full: `docs/concepts/M0-ingress.md#the-controller-has-to-land-on-the-right-node`.

## Two things about this manifest that will bite you

**The IngressClass is called `nginx` and is not the cluster default** — there is no
`ingressclass.kubernetes.io/is-default-class` annotation. Normally that means an `Ingress`
without `ingressClassName` is ignored by everyone. What saves you here is a controller flag in
this manifest, `--watch-ingress-without-class=true`, which makes it pick up class-less Ingress
objects anyway. That is a property of *this* manifest, not of ingress-nginx generally. Do not
carry the assumption to a cluster you did not set up.

**It installs a validating admission webhook**, backed by the two `ingress-nginx-admission-*`
Jobs that generate and install its TLS certificate. Between `kubectl apply` returning and those
Jobs finishing, the webhook is registered but not answering, and any `Ingress` you submit is
rejected with a webhook connection error that reads like your YAML is malformed. `make up`
waits for both Jobs and for the controller pod, so this only bites you if you apply the
manifest by hand.

## Upstream now recommends something else entirely

kind's ingress page no longer documents installing a third-party controller. It says:

> Since cloud-provider-kind v0.9.0, it natively supports Ingress. No third-party ingress
> controllers are required by default.

We do not use `cloud-provider-kind` because it is a process you run on your host and keep
running — its README says *"On macOS and WSL2 you must run cloud-provider-kind using `sudo`"*.
`make up` cannot own a foreground `sudo` process, and M0's gate is one command with no manual
steps.

Note also that ingress-nginx's own installation docs have no kind section any more; local
clusters there means minikube, MicroK8s, Docker Desktop and Rancher Desktop. The kind manifest
is still published in the repository, which is why the link at the top of this file points at
a file at a tag rather than a documentation page.

## References

```
https://github.com/kubernetes/ingress-nginx/blob/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
— the vendored file. Confirms hostPort 80/443, nodeSelector kubernetes.io/os: linux with a
control-plane toleration and no ingress-ready, --watch-ingress-without-class=true, and the
IngressClass "nginx" with no is-default-class annotation.
pinned: controller-v1.15.1  ·  checked: 2026-08-11
```
```
https://github.com/kubernetes/ingress-nginx/blob/controller-v1.12.0/deploy/static/provider/kind/deploy.yaml
— the same path one minor version earlier, still containing the ingress-ready nodeSelector.
pinned: controller-v1.12.0  ·  checked: 2026-08-11
```
```
https://kubernetes.github.io/ingress-nginx/deploy/ — install docs; source of the readiness
wait command used in the Makefile. No kind section.
checked: 2026-08-11
```
```
https://kind.sigs.k8s.io/docs/user/ingress/ — kind's current ingress page, recommending
cloud-provider-kind. Source of the quoted sentence.
pinned: kind v0.32.0  ·  checked: 2026-08-11
```
```
https://github.com/kubernetes-sigs/cloud-provider-kind — README; source of the sudo quote.
pinned: v0.11.1  ·  checked: 2026-08-11
```
