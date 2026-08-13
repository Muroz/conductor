# M0 — How your images get into the cluster

## The one-sentence version

The cluster cannot see the images sitting in your laptop's Docker, because each node is its own
container with its own image store — so you either copy images in, or run a registry both sides
can reach.

## The mental model

A **container image** is a packaged filesystem plus the metadata to start a process from it. A
**registry** is a server that stores images and hands them out. `docker pull nginx` fetches
from Docker Hub, a registry.

An image is named `registry/repository:tag`, for example `localhost:5001/conductor-api:dev`.
The **tag** is a mutable label. The **digest** (`@sha256:…`) is a hash of the content and
cannot move.

Now the important part. Your Mac's Docker daemon keeps its images in its own store. Each kind
node is a separate container running **containerd**, which keeps images in *its* own store. The
kubelet on a node asks containerd for an image. Containerd looks in its local store, and if the
image is not there, it pulls from a registry — over the network the node can see, which is the
Docker network kind created, not your Mac's loopback.

So `docker build -t conductor-api:dev .` produces an image that is completely invisible to the
cluster. The symptom is a pod stuck in `ErrImagePull`, then `ImagePullBackOff`, trying to reach
Docker Hub for a repository that only ever existed on your laptop.

There are two ways to fix that. We build both, because they teach different things.

## Way one: `kind load`

```sh
kind load docker-image conductor-api:dev --name conductor
```

This takes the image out of your Docker daemon and writes it into the containerd store of
**every node** in the cluster. kind's docs also document `kind load image-archive` for a `.tar`
produced by `docker save`.

**Good for:** no moving parts. Nothing to keep running, nothing to clean up, no networking to
understand.

**Costs:** it copies the whole image, per node. Our cluster has three, so you pay three times.
And it is a push, not a subscription — rebuild the image and the cluster still runs the old
one until you load again. That last point causes a specific and infuriating loop: you fix a
bug, redeploy, and watch the bug still happen.

## The local registry, and why the alias is needed

The other way is to run a registry your host *and* the nodes can both reach, and push to it.
kind documents a script for this. Ours is derived from it; the mechanics are worth
understanding because step 3 is the non-obvious one.

**1. Run the registry.**

```sh
docker run -d --restart=always -p "127.0.0.1:5001:5000" --network bridge --name kind-registry registry:3
```

Port 5000 inside the container, published as 5001 on your loopback. Port 5001 rather than 5000
because macOS uses 5000 for AirPlay Receiver.

**2. Join it to the cluster's network.**

```sh
docker network connect kind kind-registry
```

kind creates a Docker network called `kind` and puts the node containers on it. Connecting the
registry to that network means a node can reach it by container name: `kind-registry:5000`.

**3. Tell containerd on each node that `localhost:5001` means that registry.**

This is the step that looks unnecessary and isn't. The upstream script's own comment explains
why:

> This is necessary because localhost resolves to loopback addresses that are
> network-namespace local. In other words: localhost in the container is not localhost on the
> host.

You push to `localhost:5001` from your Mac. You want your Kubernetes manifests to say
`localhost:5001/conductor-api:dev` too, so that the same string works from both sides. But
inside a node container, `localhost` is that container — there is no registry there. So each
node gets a containerd hosts file:

```
/etc/containerd/certs.d/localhost:5001/hosts.toml
    [host."http://kind-registry:5000"]
```

Read as: "when someone asks for `localhost:5001`, actually go to `http://kind-registry:5000`."
One image name, two different routes, depending on who is asking.

The `http://` is deliberate — a plain HTTP registry, no TLS. Fine for a laptop, and the reason
you will see `http: server gave HTTP response to HTTPS client` if you ever point a tool at it
that assumes HTTPS.

**4. Write down that the registry exists.**

The script applies a ConfigMap called `local-registry-hosting` in the `kube-public` namespace.
A **ConfigMap** is a Kubernetes object holding key/value configuration data. This one holds no
configuration anything reads at runtime — it is a published convention, defined in KEP-1755, so
that other tools can discover "this cluster has a local registry at `localhost:5001`" instead
of each inventing its own flag. It is documentation with an API endpoint.

**Good for:** push once, every node pulls on demand and caches. Survives cluster deletion, so
`make down && make up` doesn't cost you a rebuild. And it is how real clusters work — the same
mental model as ECR or GCR, just smaller.

**Costs:** an extra container running on your machine, and a name (`localhost:5001/...`) baked
into manifests that only means something on this setup.

### One place we skip a step upstream still shows

kind's script passes a `containerdConfigPatches` block setting containerd's
`config_path = "/etc/containerd/certs.d"`. Its own comment says:

> NOTE: the containerd config patch is not necessary with images from kind v0.27.0+

We use kind v0.32.0's default node image, so we leave it out and say so in a comment in
`kind/cluster.yaml`. If the registry ever fails to resolve, putting that block back is the
first thing to try.

## `imagePullPolicy`: the field that decides whether any of this matters

Kubernetes has a per-container field controlling *when* the kubelet pulls. The Kubernetes docs
give three values:

- `IfNotPresent` — pull only if the image is not already in the local store.
- `Always` — ask the container runtime to pull every time a container starts. It resolves the
  tag to a digest against the registry; layers already cached are not re-downloaded.
- `Never` — never pull. Start it if it's already there, fail if it isn't.

If you omit the field, Kubernetes fills it in, and the rule depends on how you named the image:

| You wrote | Default becomes |
|---|---|
| an image with a digest | `IfNotPresent` |
| a tag that isn't `:latest` | `IfNotPresent` |
| `:latest` | `Always` |
| no tag at all | `Always` |

This is why `kind load` and `:latest` fight each other. You load an image into the node, the
pod defaults to `Always`, the kubelet asks the registry for `conductor-api:latest`, the
registry has never heard of it, and the image you just loaded is ignored. kind's docs warn
about exactly this and suggest avoiding `:latest` or setting the policy explicitly.

The Kubernetes docs add the more general version: *"You should avoid using the `:latest` tag
when deploying containers in production as it is harder to track which version of the image is
running and more difficult to roll back properly."*

`plan.md` lists "set `imagePullPolicy: Always` with tag `latest` and try to figure out which
version is running" as a trap worth walking into deliberately. It shows up in M2, when there
are pods to be confused about. The mechanism is here so that when it happens, you recognise it.

## Traps you can walk into here

**`ErrImagePull` on an image you definitely just built.** You built it on your host. Nothing
put it in the cluster. Either `kind load` it or push it to the registry.

**You rebuilt, redeployed, and the old behaviour is still there.** With `kind load`, loading is
a manual step you skipped. With the registry, you pushed a tag the node already has cached and
the policy is `IfNotPresent`. Use a new tag per build — that habit also makes rollbacks
possible, which M13 will ask for.

**The push works, the pull doesn't.** `docker push localhost:5001/x:1` succeeds from your host
and the pod still can't pull. The `hosts.toml` step didn't land on the nodes — it runs per node
and nodes created *after* the script ran don't have it.

## References

```
https://kind.sigs.k8s.io/docs/user/local-registry/ — the kind-with-registry.sh script we derive
from: registry:3 published on 127.0.0.1:5001, docker network connect kind, the
/etc/containerd/certs.d/localhost:5001/hosts.toml alias with its "localhost in the container is
not localhost on the host" explanation, the KEP-1755 local-registry-hosting ConfigMap, and the
note that the containerd config patch is unnecessary from kind v0.27.0+.
pinned: kind v0.32.0  ·  checked: 2026-08-11
```
```
https://kind.sigs.k8s.io/docs/user/quick-start/ — kind load docker-image and kind load
image-archive, and the warning that the default pull policy is Always for :latest.
pinned: kind v0.32.0  ·  checked: 2026-08-11
```
```
https://kubernetes.io/docs/concepts/containers/images/ — the three imagePullPolicy values, the
four defaulting rules in the table above, and the advice against :latest.
checked: 2026-08-11
```
```
https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
— KEP-1755, the convention behind the local-registry-hosting ConfigMap. This is the URL the
kind script's own comment points at; it resolves to a live KEP directory.
checked: 2026-08-11
```
