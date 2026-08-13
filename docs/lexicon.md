# Lexicon

Every term this project uses, in one plain sentence, grouped by the milestone where it first
appears. Appended to by `/m-start N` — earlier entries are never rewritten, so a term means
the same thing in M12 that it meant in M0.

If a concept note uses a word that isn't here, that's a bug. Say so.

---

## M0

Alphabetical.

**admission webhook** — an HTTP endpoint the API server calls before accepting an object, so
something can reject it; ingress-nginx registers one to refuse invalid Ingress rules.

**API server** — the component of the control plane that `kubectl` talks to; every read and
write to the cluster goes through it.

**cluster** — one control plane plus the nodes it schedules work onto, treated as a single
system.

**ConfigMap** — a Kubernetes object holding key/value configuration data, separate from the
code that reads it.

**containerd** — the container runtime running inside each kind node; it stores images and
starts containers when the kubelet tells it to.

**container image** — a packaged filesystem plus the metadata needed to start a process from
it.

**container runtime** — the software on a node that actually runs containers.

**context (kubectl)** — a saved triple of (cluster, user, namespace) telling `kubectl` where to
send commands and as whom.

**control-plane node** — a node running the components that make cluster-wide decisions: API
server, scheduler, controller manager, etcd.

**controller manager** — the control-plane component running the loops that notice when reality
differs from the declared desired state, and act to close the gap.

**current-context** — the one context `kubectl` is using right now; read it with
`kubectl config current-context`.

**DaemonSet** — a Kubernetes object that runs exactly one copy of a pod on every node.

**Deployment** — a Kubernetes object that keeps a stated number of identical pods running and
replaces them when they die.

**digest** — the `@sha256:…` hash of an image's exact contents; unlike a tag, it cannot be
moved to point at something else.

**endpoints** — the list of pod IPs currently behind a Service; empty endpoints is why a
request reaches nginx and comes back 503 rather than 404.

**ErrImagePull** — the pod status meaning the kubelet tried to fetch the image and failed;
repeated failures become `ImagePullBackOff`.

**etcd** — the key/value database where the cluster stores all of its state.

**Gateway API** — a newer set of Kubernetes routing objects intended to succeed Ingress;
mentioned here only because `cloud-provider-kind` implements Ingress by translating into it.

**extraPortMappings** — a kind cluster-config field that publishes a port from a node container
onto your host machine, the same idea as `docker run -p`.

**hostPort** — a container field asking to bind a port directly on the node the pod is running
on, bypassing the normal pod network.

**imagePullPolicy** — a per-container field deciding when the kubelet pulls the image:
`Always`, `IfNotPresent`, or `Never`.

**ImagePullBackOff** — the pod status meaning the kubelet has repeatedly failed to fetch the
image and is now waiting longer between attempts.

**Ingress** — a Kubernetes object holding HTTP routing rules: hostnames and paths on one side,
Services on the other. Data only; something has to act on it.

**ingress controller** — the pod that watches Ingress objects and actually proxies the traffic;
without one, an Ingress does nothing.

**IngressClass** — an object naming a controller implementation, so an Ingress can declare
which controller should own it.

**Job (Kubernetes)** — a workload that runs a pod to completion once, rather than keeping it
running.

**KEP** — Kubernetes Enhancement Proposal, the design document format used to agree on
Kubernetes changes and conventions.

**kind** — a tool that runs a Kubernetes cluster by starting one Docker container per node.

**kubeadm** — the tool kind uses inside each node container to bootstrap Kubernetes; its config
format is versioned (`v1beta3`, `v1beta4`).

**kubeconfig** — the file listing clusters, users and contexts that `kubectl` reads to decide
where to connect; `~/.kube/config` by default.

**KUBECONFIG** — an environment variable holding a list of kubeconfig file paths, merged
together when set.

**kubectl** — the command-line client for the Kubernetes API server.

**kubelet** — the agent on each node that asks the API server what should run there and tells
the container runtime to run it.

**label** — a key/value tag attached to a Kubernetes object, used by selectors to find it.

**LoadBalancer (Service type)** — a Service that asks the surrounding infrastructure for an
external IP; a kind cluster has no infrastructure to ask, which is why ingress needs a
different route in.

**manifest** — a YAML file describing a Kubernetes object you want to exist.

**namespace** — a name-scoping boundary inside a cluster; two objects can share a name if they
are in different namespaces.

**node** — a machine Kubernetes schedules work onto. With kind, each node is a Docker
container.

**node image** — the `kindest/node` Docker image kind starts node containers from; it
determines the Kubernetes version.

**nodeSelector** — a pod field listing labels a node must have for the pod to be scheduled
there.

**pod** — the smallest thing Kubernetes schedules: one or more containers sharing a network
address and lifecycle.

**registry** — a server that stores container images and serves them to whoever pulls.

**scheduler** — the control-plane component that decides which node each new pod runs on.

**selector** — a query over labels, used by objects like Services to decide which pods they
apply to.

**Service** — a stable address for a changing set of pods, chosen by a label selector.

**tag** — the human-readable label on an image name (`:dev`, `:1.0`, `:latest`); it can be
moved to a different image at any time.

**caBundle** — the certificate authority data on a webhook's config, used by the API server to
verify the webhook's TLS certificate; without it the API server refuses to call the webhook.

**taint** — a mark on a node that repels pods unless they explicitly tolerate it.

**ttlSecondsAfterFinished** — a Job field saying how long to keep the Job object after it
completes; `0` means delete it immediately.

**toleration** — a pod field saying it accepts a particular node taint; it permits scheduling
there, it does not force it.

**version skew** — the difference in Kubernetes minor version between two components;
`kubectl` is supported within one minor version of the API server, either direction.

**worker node** — a node that runs workloads only, with no control-plane components.
