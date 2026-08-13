# M0 — Which cluster is `kubectl` actually talking to?

## The one-sentence version

A **context** is a saved answer to three questions — which cluster, as which user, in which
namespace — and `kubectl` uses exactly one of them at a time, silently.

## The mental model

`kubectl` is a client. It has no cluster of its own. Every command it runs is an HTTP request
to some API server, and it decides which one by reading a file.

That file is the **kubeconfig**. kind's docs state that by default it lives at
`${HOME}/.kube/config` when the `$KUBECONFIG` environment variable is not set.

Inside it are three lists and one pointer:

- **clusters** — API server addresses and their certificates.
- **users** — credentials.
- **contexts** — named combinations. The Kubernetes docs put it exactly this way: *"Each
  context is a triple (cluster, user, namespace)."*
- **current-context** — the name of the one context in use right now.

A **namespace** is a name-scoping boundary inside a cluster. Two objects can both be called
`api` if they live in different namespaces. If a context sets a namespace, commands that don't
say `-n something` operate there.

The command that answers "where am I?" is:

```sh
kubectl config current-context
```

And the one that moves you:

```sh
kubectl config use-context kind-conductor
```

## What kind does to your kubeconfig

When you run `kind create cluster --name conductor`, kind writes a cluster, a user, and a
context into your kubeconfig, and switches `current-context` to the new one. The naming rule
is fixed: the context is `kind-` plus the cluster name. kind's docs show
`kubectl cluster-info --context kind-kind-2` for a cluster named `kind-2`.

So ours is `kind-conductor`. That string appearing in `kubectl config current-context` is the
first thing to check when anything is confusing, and it is step 2 of M0's gate for that reason.

`kind delete cluster` removes those entries again. If your current context was the one deleted,
you are left pointing at nothing, and `kubectl get pods` fails with a connection error rather
than a helpful message.

`kind get clusters` lists the kind clusters that exist, independently of what your kubeconfig
believes.

## Why this matters more than it sounds

The failure mode is not "I get an error". It is "the command worked, somewhere else".

`kubectl` gives no visual signal of which cluster it is hitting. The prompt looks the same.
The output looks the same. If you have a work cluster in the same kubeconfig and your current
context is still pointing at it from this morning, then `kubectl delete deployment api` deletes
a deployment called `api` — on the work cluster. It will succeed. It will look exactly like it
looked when you rehearsed it locally.

This is the reason experienced people install prompt widgets showing the current context, and
the reason M4 introduces a rule that `kubectl` becomes read-only in your head. In this project
you only have one cluster to hit, so the stakes are low — which makes M0 the cheap moment to
build the habit.

Two habits worth having by the end of this milestone:

1. `kubectl config current-context` before anything you cannot undo.
2. `make up` prints the context it just switched you to, so the answer is in your scrollback
   without you asking.

## The tradeoff: one file or several

`KUBECONFIG` can hold a list of paths. The Kubernetes docs describe it as *"a list of paths to
configuration files"*, colon-delimited on Linux and macOS, and kind's docs add that when it is
set, the files are merged, with modifications saved back into whichever file held that block.

- **One merged file** (the default, `~/.kube/config`) — everything in one place, one context
  switch away. Convenient, and exactly what makes the wrong-cluster accident possible.
- **Separate files per cluster**, selected by `KUBECONFIG` per terminal — a work terminal
  cannot touch a personal cluster, because the file isn't loaded. Safer, more setup, and easy
  to forget in a new shell.
- **`kind create cluster --kubeconfig <path>`** — kind's docs say that when the flag is used,
  *"only that file is loaded. The flag may only be set once and no merging takes place."* Full
  isolation for this cluster alone.

We take the default: one merged file. There is one cluster in this project, and adding a
`KUBECONFIG` export that you must remember in every terminal buys safety we don't currently
need — at the cost of a step that is easy to get wrong. If you already have work clusters in
`~/.kube/config`, that calculation changes, and it is a fair thing to raise at review.

## Traps you can walk into here

**A second terminal with a stale environment.** You export `KUBECONFIG` in one tab, open
another, and the new tab has the old value — or none. Both tabs run identical commands against
different clusters. The symptom is an object you *just created* not existing.

**Your current context vanished.** You ran `make down`. Now `kubectl get nodes` reports it
cannot connect to `127.0.0.1:<port>`. Nothing is wrong except that the cluster the context
names no longer exists.

**Kubernetes version skew between `kubectl` and the cluster.** Your `kubectl` is whatever brew
installed; the cluster is whatever the kind node image ships. Usually harmless — Kubernetes
supports a version skew of one minor release either way — but if a flag "doesn't exist", check
`kubectl version` before assuming the docs are wrong.

## References

```
https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/
— defines a context as a (cluster, user, namespace) triple, shows current-context,
kubectl config use-context, and the KUBECONFIG list semantics.
checked: 2026-08-11
```
```
https://kind.sigs.k8s.io/docs/user/quick-start/ — the "Interacting With Your Cluster" section:
kubeconfig defaults to ${HOME}/.kube/config when $KUBECONFIG is unset, $KUBECONFIG is a merged
list, the kind-<name> context naming, kind get clusters, and the --kubeconfig flag's
no-merging behaviour.
pinned: kind v0.32.0  ·  checked: 2026-08-11
```
