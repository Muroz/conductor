# M0 — What a kind cluster is made of

## The one-sentence version

kind runs a Kubernetes cluster by starting one Docker container per node and installing
Kubernetes inside those containers.

That is the whole trick. "kind" stands for **K**ubernetes **in** **D**ocker.

## The mental model

A **node** is a machine that Kubernetes schedules work onto. In a data centre a node is a
server. With kind, a node is a Docker container running on your laptop.

There are two roles.

- A **control-plane node** runs the parts of Kubernetes that make decisions: the API server
  (the thing `kubectl` talks to), the scheduler (decides which node each pod goes on), the
  controller manager (notices when reality differs from what you asked for and fixes it), and
  etcd (the database holding all cluster state).
- A **worker node** runs your workloads and nothing else.

On every node there is a **kubelet** — an agent that talks to the API server, asks "what should
be running here?", and tells the local **container runtime** to start it. The container runtime
in a kind node is **containerd**. A **pod** is what actually gets started: one or more
containers that share a network address and are scheduled together as a unit.

So the layering is:

```
your laptop
└── Docker
    ├── conductor-control-plane   (a container, and a Kubernetes node)
    │   └── containerd
    │       └── pods: apiserver, etcd, scheduler, ingress-nginx, …
    ├── conductor-worker          (a container, and a Kubernetes node)
    └── conductor-worker2
```

Two commands look at two different layers of that picture, and mixing them up is a common
early confusion:

- `docker ps` shows you the **nodes**.
- `kubectl get pods -A` shows you what is running **inside** them.

## The config file is read once

`kind create cluster --config kind/cluster.yaml` reads that file exactly once, at creation.

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: conductor
nodes:
- role: control-plane
- role: worker
```

`kind` and `apiVersion` here identify the file's own schema — this is a config file for the
kind tool, not a Kubernetes object you submit to a cluster. `name` decides the container names
(`conductor-control-plane`) and the kubectl context name (`kind-conductor`).

After creation, the file is inert. Editing it changes nothing. Adding a node, changing a port
mapping, changing the Kubernetes version — all of them mean deleting the cluster and creating
it again.

**Why the design is this way.** kind is a testing tool. Its authors optimised for "throw it
away and make a new one", not "evolve it in place". A real cluster has a whole discipline
around node lifecycle; kind sidesteps it by making the cluster cheap to destroy.

**What this means for you.** `make down && make up` is not a recovery procedure, it is your
normal edit-test loop for anything at the cluster level. That is exactly why M0's gate is a
stopwatch. A three-minute rebuild you run twenty times is fine. A twelve-minute one quietly
teaches you to patch things by hand instead — which is the habit M4 is going to ban.

## Port mappings: getting traffic into a node

Here is the problem. The node is a Docker container. A process listening on port 80 inside
that container is not listening on port 80 on your Mac. Nothing bridges them by default.

`extraPortMappings` is that bridge. It is `docker run -p`, declared in the cluster config:

```yaml
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    listenAddress: "127.0.0.1"
    protocol: TCP
```

- `containerPort` — the port on the node.
- `hostPort` — the port on your laptop.
- `listenAddress` — which of your laptop's addresses to bind. kind's docs state `0.0.0.0` is
  the default, meaning every network interface. `127.0.0.1` restricts it to your own machine.
- `protocol` — `TCP`, `UDP` or `SCTP`. TCP is the default.

Two things follow, and both bite people.

**The mapping belongs to one node, not to the cluster.** If you declare it on the
control-plane node and a pod that wants port 80 gets scheduled onto a worker, the port on your
laptop leads to a node where nothing is listening. See
`M0-ingress.md#the-controller-has-to-land-on-the-right-node`.

**Two nodes cannot both map host port 80.** Docker will refuse the second bind. This is why
"just put the mapping on every node" is not a fix.

## Multi-node: what it costs and what it buys

kind will happily give you one node. Our cluster has three: one control-plane, two workers.

What it costs:

- Cluster creation is slower — three containers to start, and kubeadm to join two of them.
- `kind load docker-image` copies the image into **every** node's containerd store. Three
  copies of a Python image is real seconds in M1.
- Scheduling stops being a foregone conclusion. On one node, every pod goes to that node. On
  three, "where did it go?" becomes a question you have to answer, and sometimes control.

What it buys:

- `nodeSelector`, node affinity, and DaemonSets stop being words and become things you can
  watch happen. M2 asks you to explain every field in your YAML; you cannot explain a
  `nodeSelector` you never saw do anything.
- You get the wrong-node failure mode at least once, cheaply, in M0 — rather than for the first
  time in a later milestone where three other new things are also in play.

## Node images and version pinning

The Kubernetes version comes from the **node image** — the Docker image kind uses for the node
containers, published as `kindest/node`.

kind v0.32.0's release notes state its default is
`kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5`,
and say you *must* use the `@sha256` digest to be sure you get an image built for that kind
release. A **digest** is a hash of the exact image contents; a **tag** is a label that can be
moved to point somewhere else tomorrow. Pinning by digest is how "reproducible" stops being
aspirational.

The same release notes carry two changes that matter if you copy a config snippet off a blog
post written a year ago:

- **kubeadm config format v1beta4** is now used for Kubernetes 1.36.0+. Older tutorials write
  `kubeadmConfigPatches` targeting `v1beta3`. kind converts unversioned patches automatically,
  but a patch that names `v1beta3` explicitly will not do what you expect.
- **Envoy replaced HAProxy** as the load balancer in multi-control-plane clusters. We have one
  control-plane node, so this doesn't touch us. It is here so that when you read the release
  notes yourself, you know why we skipped it.

## Traps you can walk into here

**You edit `kind/cluster.yaml` and nothing changes.** No error, no warning. The cluster keeps
running with the config it was born with. The symptom is `curl` on your new port hanging
forever while every `kubectl` command says everything is healthy. The fix is always
`make down && make up`.

**Host port 80 is already taken.** `kind create cluster` fails partway with a Docker error
along the lines of `bind: address already in use`, and leaves you with a partially created
cluster — some node containers exist, the cluster doesn't work. `make reset` clears it. Then
either free the port or move to 8080.

**A pod says `Running` and `curl localhost` says connection refused.** Nothing is broken from
Kubernetes' point of view: the pod is healthy, it just isn't on the node your port mapping
leads to. `kubectl get pod -o wide` shows the `NODE` column and answers this in one line.

## References

```
https://kind.sigs.k8s.io/docs/user/configuration/ — the complete cluster config schema:
name, nodes and roles, extraPortMappings with its four fields and their defaults,
kubeadmConfigPatches for node labels.
pinned: kind v0.32.0  ·  checked: 2026-08-11
```
```
https://kind.sigs.k8s.io/docs/user/quick-start/ — kind create cluster --config, kind get clusters,
kind delete cluster, and the note that the default cluster name is "kind".
pinned: kind v0.32.0  ·  checked: 2026-08-11
```
```
https://github.com/kubernetes-sigs/kind/releases/tag/v0.32.0 — the default node image and its
sha256 digest, the "you must use the @sha256 digest" statement, the kubeadm v1beta4 switch for
Kubernetes 1.36+, and the HAProxy → Envoy change for HA clusters.
pinned: v0.32.0, released 2026-06-02  ·  checked: 2026-08-11
```
