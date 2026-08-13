# Conductor — cluster lifecycle.
#
# The only interface you need in M0:
#
#   make up      create the cluster, the registry and ingress; wait until it is usable
#   make down    delete the cluster (the registry container stays)
#   make reset   make down, plus delete the registry and everything pushed to it
#   make load    copy a locally built image into the cluster: make load IMG=name:tag
#
# See docs/walkthroughs/M0.md

.PHONY: up down reset load

# ?= so the name can be overridden from the environment without editing this file.
# kind/cluster.yaml carries the same name; both must agree.
CLUSTER ?= conductor

# kind derives the kubectl context name from the cluster name: "kind-" + name.
CONTEXT := kind-$(CLUSTER)

REGISTRY_CONTAINER := kind-registry

INGRESS_MANIFEST := k8s/ingress-nginx/deploy-v1.15.1.yaml

# ---------------------------------------------------------------------------------------
# up — from nothing to a cluster you can use.
#
# "Usable" is the point of the three waits at the end. Without them `make up` returns as soon
# as the objects are submitted, and your first `kubectl apply -f ingress.yaml` fails with a
# webhook error that looks like your YAML is wrong.
# ---------------------------------------------------------------------------------------
up:
	@echo "==> creating cluster $(CLUSTER)"
	kind create cluster --name $(CLUSTER) --config kind/cluster.yaml

	@echo "==> local registry"
	./scripts/registry.sh $(CLUSTER)

	@echo "==> ingress-nginx (vendored, see k8s/ingress-nginx/README.md)"
	kubectl --context $(CONTEXT) apply -f $(INGRESS_MANIFEST)

	@echo "==> waiting for ingress to be usable"
# Three waits, in this order. Each covers a gap the next one does not:
#
# 1. rollout status, not `kubectl wait pod`. The Deployment object exists the instant apply
#    returns, but its pods may not — and `kubectl wait pod` on a selector that matches nothing
#    fails outright with "no matching resources found" rather than waiting.
	kubectl --context $(CONTEXT) -n ingress-nginx rollout status \
		deploy/ingress-nginx-controller --timeout=180s
# 2. The admission webhook's caBundle.
#
#    Two Jobs set this up: -create generates the TLS certificate, -patch writes the CA bundle
#    into the ValidatingWebhookConfiguration. Until -patch has run, the API server has no way
#    to verify the webhook's certificate, and `kubectl apply` of any Ingress fails with an
#    x509 error. Controller readiness does not imply -patch has finished.
#
#    But you cannot wait on those Jobs: both carry `ttlSecondsAfterFinished: 0`, so the TTL
#    controller deletes them the moment they complete — usually before wait #1 above has even
#    returned. `kubectl wait job/...` then fails with NotFound, which is indistinguishable
#    from "never ran".
#
#    So wait on what -patch produces instead. The vendored manifest ships the webhook with no
#    caBundle field at all; its appearance is the signal. A --for=jsonpath with no `=value`
#    waits for the field to become non-empty.
	kubectl --context $(CONTEXT) wait --for=jsonpath='{.webhooks[0].clientConfig.caBundle}' \
		validatingwebhookconfiguration/ingress-nginx-admission --timeout=120s
# 3. The readiness check from ingress-nginx's own install docs, kept verbatim so it is
#    recognisable when you read that page.
#    https://kubernetes.github.io/ingress-nginx/deploy/ (checked 2026-08-11)
	kubectl --context $(CONTEXT) wait --namespace ingress-nginx --for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller --timeout=120s

# Printed because kubectl gives no other signal of which cluster it is talking to, and the
# wrong-cluster mistake is silent. See docs/concepts/M0-kubectl-context.md
	@echo
	@echo "==> ready. kubectl context: $$(kubectl config current-context)"

# ---------------------------------------------------------------------------------------
# down — delete the cluster.
#
# TODO(learn): this deliberately leaves the $(REGISTRY_CONTAINER) container running.
#
# It is the layer cache. If `down` removed it, every `up` would need a full `docker push` of
# the application image before anything could start — and from M1 on you will run down/up
# often. `make reset` is the target that makes the strong promise.
#
# The defensible alternative is that "down" should mean nothing is left. A container that
# survives `make down` is exactly the kind of hidden state that makes a setup work on your
# machine and nowhere else. The counter-argument is that nothing here is load-bearing: `up`
# recreates the registry from scratch if it is gone, so the state is a cache, not a
# dependency. Judgement call — argue with it at review.
# ---------------------------------------------------------------------------------------
down:
	@echo "==> deleting cluster $(CLUSTER)"
	kind delete cluster --name $(CLUSTER)
	@echo "==> note: registry container $(REGISTRY_CONTAINER) left running (make reset removes it)"

# ---------------------------------------------------------------------------------------
# reset — down, and take the registry with it.
#
# Use before timing `make up`, so you are measuring a real cold start and not a warm cache.
# Also the way out of a half-created cluster, e.g. when host port 80 was already taken and
# `kind create cluster` failed partway.
#
# `-` prefix: keep going if the step fails. `reset` must work when there is nothing to delete.
# ---------------------------------------------------------------------------------------
reset:
	@echo "==> deleting cluster $(CLUSTER) (ignoring errors)"
	-kind delete cluster --name $(CLUSTER)
	@echo "==> removing registry container $(REGISTRY_CONTAINER) and its images"
	-docker rm -f $(REGISTRY_CONTAINER)

# ---------------------------------------------------------------------------------------
# load — put a locally built image into the cluster.
#
#   make load IMG=conductor-api:dev
#
# Nothing to load until M1 builds an image. It exists now because "how does an image get in"
# is M0's syllabus, and having both routes side by side is the point.
#
# This is the `kind load` route: it copies the image out of your Docker daemon into the
# containerd store of EVERY node — three copies here. Simple, no moving parts, and a push not
# a subscription: rebuild the image and the cluster keeps running the old one until you load
# again.
#
# The other route is the local registry: `docker push localhost:5001/name:tag`, and nodes pull
# on demand. See docs/concepts/M0-images-into-the-cluster.md for when each one is right.
# ---------------------------------------------------------------------------------------
load:
# The guard runs in the shell, not as a make `ifndef`. Make conditionals are evaluated when
# the file is read, so an `ifndef IMG` here would abort `make up` too.
	@test -n "$(IMG)" || { echo "IMG is not set. Usage: make load IMG=name:tag" >&2; exit 1; }
	@echo "==> loading $(IMG) into every node of $(CLUSTER)"
	kind load docker-image $(IMG) --name $(CLUSTER)
