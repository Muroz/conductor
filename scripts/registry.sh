#!/usr/bin/env bash
#
# Start a local container registry and wire the kind cluster's nodes to it.
#
# Derived from kind's kind-with-registry.sh, minus the cluster creation — the Makefile owns
# that, and this runs against a cluster that already exists.
#   https://kind.sigs.k8s.io/docs/user/local-registry/ (checked 2026-08-11)
#
# Idempotent: `make up` calls it on every cluster creation, and the registry container
# survives `make down`, so most runs skip step 1 entirely.
#
# See docs/concepts/M0-images-into-the-cluster.md

set -euo pipefail

# Cluster name comes from the Makefile so there is one place that knows it.
CLUSTER="${1:-conductor}"

REG_NAME='kind-registry'

# 5001, not 5000. On macOS, port 5000 is taken by AirPlay Receiver (ControlCenter), which
# answers requests instead of failing to bind — so a registry on 5000 appears to work and then
# returns nonsense. kind's own docs use 5001 for the same reason.
REG_PORT='5001'

# ---------------------------------------------------------------------------------------
# 1. The registry container.
#
# --restart=always so it comes back with Docker, and survives `make down`. It holds every
# image you have pushed; deleting it means re-pushing the whole application image before the
# next `make up` can start anything. `make reset` is the target that removes it.
#
# Published on 127.0.0.1 only — same reasoning as the cluster's port mappings. Container port
# 5000 is what the registry image listens on; 5001 is what this machine sees.
# ---------------------------------------------------------------------------------------
if [ "$(docker inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)" != 'true' ]; then
  echo "==> creating local registry ${REG_NAME} on 127.0.0.1:${REG_PORT}"
  docker run \
    -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --network bridge --name "${REG_NAME}" \
    registry:3
else
  echo "==> local registry ${REG_NAME} already running"
fi

# ---------------------------------------------------------------------------------------
# 2. Teach containerd on each node that "localhost:5001" means the registry container.
#
# This is the step that looks redundant and is not. Quoting kind's script:
#
#   This is necessary because localhost resolves to loopback addresses that are
#   network-namespace local. In other words: localhost in the container is not localhost on
#   the host.
#
# You push to localhost:5001 from this machine. You want manifests to say
# localhost:5001/conductor-api:dev so the same string works from both sides. Inside a node
# container, localhost is that container — there is no registry there. So each node gets an
# alias file: "when asked for localhost:5001, go to http://kind-registry:5000 instead".
#
# Plain http:// — no TLS on a laptop registry. That is why any tool assuming HTTPS reports
# `http: server gave HTTP response to HTTPS client`.
#
# Runs per node. A node created after this ran does not have the file — but kind clusters are
# created whole, so in practice that means "re-run after `make up`", not "patch a node".
# ---------------------------------------------------------------------------------------
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${REG_PORT}"
for node in $(kind get nodes --name "${CLUSTER}"); do
  echo "==> configuring ${node} to resolve localhost:${REG_PORT}"
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${REG_NAME}:5000"]
EOF
done

# ---------------------------------------------------------------------------------------
# 3. Put the registry on the cluster's Docker network.
#
# kind creates a Docker network called "kind" and attaches the node containers to it. Without
# this, the alias above points at a hostname the nodes cannot resolve, and pulls fail with a
# DNS error rather than anything that mentions the registry.
#
# The guard matters: `docker network connect` errors if already connected, and `set -e` would
# abort `make up` on the second run.
# ---------------------------------------------------------------------------------------
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REG_NAME}")" = 'null' ]; then
  echo "==> connecting ${REG_NAME} to the kind network"
  docker network connect "kind" "${REG_NAME}"
fi

# ---------------------------------------------------------------------------------------
# 4. Write down that the registry exists.
#
# Nothing reads this at runtime. It is a published convention (KEP-1755) so that tools can
# discover "this cluster has a local registry at localhost:5001" instead of each inventing
# its own flag. Documentation with an API endpoint.
#   https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
#
# kube-public is the namespace for things meant to be readable by everyone, including
# unauthenticated clients.
#
# --context is explicit: this script writes to a cluster, and picking the wrong one is the
# quiet failure mode of every kubectl command. See docs/concepts/M0-kubectl-context.md
# ---------------------------------------------------------------------------------------
echo "==> publishing the local-registry-hosting ConfigMap"
cat <<EOF | kubectl --context "kind-${CLUSTER}" apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
