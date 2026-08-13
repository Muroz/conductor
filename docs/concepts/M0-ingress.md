# M0 — How an HTTP request reaches a pod

## The one-sentence version

An **Ingress** is a rule saying "requests for this path go to that Service"; an **Ingress
controller** is the pod that reads those rules and actually proxies the traffic — and without a
controller running, an Ingress rule does nothing at all.

## The mental model

Three objects, in order.

A **pod** is one or more containers running together, with its own IP address. Pods are
disposable — they get replaced, and the replacement has a different IP.

A **Service** is a stable address for a set of pods. You give it a **selector** — a query over
**labels**, which are just key/value tags on objects — and it forwards traffic to whichever
pods currently match. Pods come and go; the Service address doesn't.

An **Ingress** is a routing table for HTTP: hostnames and paths on one side, Services on the
other. It is only data. Submitting one to the API server changes nothing by itself.

The thing that makes it real is the **ingress controller**: a pod that watches the API server
for Ingress objects, rewrites its own proxy configuration to match, and serves the traffic. We
use ingress-nginx, which is nginx plus a control loop that keeps nginx's config in sync with
what is in the cluster.

An **IngressClass** connects the two. It names a controller implementation, and an Ingress can
say `ingressClassName: nginx` to declare which controller should own it. This exists because a
cluster can run more than one controller, and without the field they would both try to serve
the same rule.

The path a request takes, once everything is up:

```
your browser  →  localhost:80
              →  (kind extraPortMapping)   host port 80 → node container port 80
              →  the ingress-nginx pod, using hostPort 80 on that node
              →  nginx matches the request path against the Ingress rules
              →  the Service named in the rule
              →  one of the pods behind that Service
```

## Why kind needs help getting traffic in

On a cloud provider you would not do any of this. You would create a Service of type
`LoadBalancer`, the cloud controller would provision a real load balancer with a real external
IP, and traffic would arrive.

kind has no cloud. Nothing hands out external IPs. So we go one layer lower: the ingress
controller container asks for **hostPort** 80 and 443 — meaning "bind these ports on the node I
am running on" — and the cluster config maps your laptop's ports 80 and 443 into that node.
Two bridges, host → node → pod.

You can verify the first half in the manifest we vendor. The controller container declares:

```yaml
ports:
- containerPort: 80
  hostPort: 80
  name: http
```

`hostPort` is generally something to avoid — it makes a pod unschedulable anywhere the port is
already taken, and it punches through the pod network abstraction. For an ingress controller on
a laptop it is the mechanism that makes the whole thing work with no cloud underneath.

## The controller has to land on the right node

Our cluster has three nodes and only one of them has the port mapping. So the controller pod
must land on that node — the control-plane node. If it lands on a worker, everything reports
healthy and `curl localhost` gets connection refused.

The **scheduler** decides placement. You constrain it with `nodeSelector`: a set of labels a
node must have for the pod to be eligible.

Here is where you have to be careful with anything you read online. The ingress-nginx kind
manifest **used to** carry `nodeSelector: ingress-ready: "true"`, which is why every kind
tutorial tells you to label a node `ingress-ready=true`. It doesn't any more. Checked on
2026-08-11 against the repository:

| Tag | `ingress-ready` in `deploy/static/provider/kind/deploy.yaml` |
|---|---|
| `controller-v1.11.5` | present |
| `controller-v1.12.0` | present |
| `controller-v1.13.9` | **gone** |
| `controller-v1.14.5` | gone |
| `controller-v1.15.1` (what we vendor) | gone |

What v1.15.1 has instead is:

```yaml
nodeSelector:
  kubernetes.io/os: linux
tolerations:
- effect: NoSchedule
  key: node-role.kubernetes.io/control-plane
  operator: Equal
```

A **taint** is a mark on a node that repels pods; a **toleration** is a pod saying it accepts a
particular taint. Control-plane nodes are tainted by default so ordinary workloads stay off
them. The toleration above means the controller *may* run on a control-plane node — not that it
must.

On a single-node kind cluster that distinction never surfaces: there is one node, so it goes
there. On our three-node cluster the scheduler is free to choose a worker. So we add the
`nodeSelector` back ourselves, and label the control-plane node in `kind/cluster.yaml` to
match. The label name `ingress-ready` is kept because that is what every kind guide you find
will call it.

This is the milestone's first lesson in reading a manifest instead of trusting a tutorial about
it.

## Where we diverge from what kind now recommends

kind's ingress page has been rewritten. It no longer describes installing a third-party
controller. It says:

> Since cloud-provider-kind v0.9.0, it natively supports Ingress. No third-party ingress
> controllers are required by default.

and points you at each controller's own docs if you want one anyway. `cloud-provider-kind` is a
separate tool that gives a kind cluster the missing cloud-provider behaviour: it watches for
`LoadBalancer` Services and creates real proxy containers for them. Its v0.9.0 release notes
confirm the Ingress support, and describe how it works — a controller that mirrors Ingress
objects into Gateway API objects and serves them that way.

**What we do instead:** install ingress-nginx from its pinned kind manifest, using
`hostPort` + `extraPortMappings`.

**The concrete reason:** `cloud-provider-kind` is not something the cluster runs. Its README
says *"Once the cluster is running, we need to run the `cloud-provider-kind` in a terminal and
keep it running"*, and *"On macOS and WSL2 you must run cloud-provider-kind using `sudo`"*.
M0's gate is one command, under three minutes, no manual steps. A `make up` that finishes by
telling you to open another terminal and type a `sudo` command has failed that gate. A second
reason, smaller but real: ingress-nginx is what you will meet in almost any real cluster, and
M2 asks you to explain every field of an Ingress you wrote.

There is a related documentation gap worth knowing about. ingress-nginx's own installation page
has no kind section either — it covers minikube, MicroK8s, Docker Desktop and Rancher Desktop
under local clusters, and cloud providers. The kind manifest still exists in the repository at
`deploy/static/provider/kind/deploy.yaml`. That is why our reference points at a file at a tag
rather than a documentation page: the docs no longer describe the thing we install, but the
thing is still maintained and still published.

## The admission webhook, and why `make up` waits

The manifest installs more than a proxy. Among its 19 objects are two Jobs and a
`ValidatingWebhookConfiguration`.

An **admission webhook** is an HTTP endpoint the API server calls before it accepts an object,
so that something can say "no". ingress-nginx registers one for `Ingress` objects — it checks
that your rules produce a valid nginx config, which turns a whole class of typos into an
immediate rejection instead of a silently broken route.

That webhook needs a TLS certificate, and the certificate is created by a Kubernetes **Job** —
a one-shot workload that runs to completion — included in the manifest. Between `kubectl apply`
returning and that Job finishing, the webhook is registered but not answering. Any `Ingress`
you submit in that window is rejected with a webhook connection error that looks like your YAML
is malformed.

So `make up` ends with:

```sh
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=120s
```

which is the command ingress-nginx's own install docs give. It makes `make up` returning mean
"ready to use", not "objects submitted".

## Traps you can walk into here

**Every pod is `Running`, `curl localhost` is connection refused.** The controller is on a node
with no port mapping. `kubectl -n ingress-nginx get pods -o wide` and read the `NODE` column.

**nginx answers, but with 404.** The controller is working — you reached it. No Ingress rule
matches the path you asked for. A 404 from nginx and a connection refused mean opposite
things: one says the plumbing is right and the routing is wrong.

**nginx answers, but with 503.** A rule *did* match — nginx knew where to send you and found
nothing there. 503 means the Service behind the rule has no ready endpoints: either its
selector matches no pods, or the pods it matches are not ready yet. Reach for
`kubectl get endpoints <service>`; an empty `ENDPOINTS` column is the whole diagnosis. On a
freshly applied example this is usually just timing — the pod is still pulling its image on
whichever node it landed on, and each node pulls independently.

**Your first `kubectl apply -f ingress.yaml` fails with a webhook error.** Ran too early, before
the certificate Job finished. Wait and retry.

**An Ingress with no `ingressClassName` gets ignored.** In general this is real: the vendored
manifest's IngressClass is named `nginx` and is *not* marked as the cluster default. What saves
you here is that the controller runs with `--watch-ingress-without-class=true`, so it picks up
class-less Ingress objects anyway. That is a property of this specific manifest, not of
ingress-nginx generally — do not carry the assumption to a cluster you did not set up.

## References

```
https://github.com/kubernetes/ingress-nginx/blob/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
— the manifest we vendor. 679 lines, 19 objects. Confirms: containerPort/hostPort 80 and 443,
nodeSelector kubernetes.io/os: linux with a control-plane toleration and no ingress-ready,
controller args including --watch-ingress-without-class=true, IngressClass "nginx" with no
is-default-class annotation, and the admission-webhook Jobs.
pinned: controller-v1.15.1, released 2026-03-19  ·  checked: 2026-08-11
```
```
https://github.com/kubernetes/ingress-nginx/blob/controller-v1.12.0/deploy/static/provider/kind/deploy.yaml
— the same file one minor version earlier, which still contains the ingress-ready nodeSelector.
The comparison in the table above was made by fetching both files.
pinned: controller-v1.12.0  ·  checked: 2026-08-11
```
```
https://kubernetes.github.io/ingress-nginx/deploy/ — the install page. Source of the kubectl
wait command. Note it has no kind section; local-cluster coverage is minikube, MicroK8s,
Docker Desktop and Rancher Desktop.
checked: 2026-08-11
```
```
https://kind.sigs.k8s.io/docs/user/ingress/ — kind's current ingress page, which recommends
cloud-provider-kind and no longer documents the ingress-ready / extraPortMappings setup.
Source of the quoted sentence about v0.9.0.
pinned: kind v0.32.0  ·  checked: 2026-08-11
```
```
https://github.com/kubernetes-sigs/cloud-provider-kind — README. Source of the quotes about
running it in a terminal and needing sudo on macOS and WSL2.
pinned: v0.11.1, released 2026-06-26  ·  checked: 2026-08-11
```
```
https://github.com/kubernetes-sigs/cloud-provider-kind/releases/tag/v0.9.0 — release notes:
"Support Ingress API via Gateway API", describing the mirroring of Ingress objects into Gateway
and HTTPRoute objects.
pinned: v0.9.0, released 2025-10-27  ·  checked: 2026-08-11
```
```
https://kind.sigs.k8s.io/examples/ingress/usage.yaml — the two agnhost pods, two Services and
one Ingress used as the smoke test in the walkthrough. Its Ingress has no ingressClassName.
checked: 2026-08-11
```
