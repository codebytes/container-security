REGISTRY ?= 127.0.0.1:5000
IMAGE_NAME ?= guardian-demo-app
TAG ?= v0.1.0-secure
IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(TAG)
SBOM := ../artifacts/sbom.json
COSIGN_KEY ?= ../cosign.key
COSIGN_PUB ?= ../cosign.pub

# cosign 3.0.6 defaults to the new OCI-referrer bundle format which Kyverno's
# verifyImages reader can't find ("no signatures found"). Force the legacy .sig
# format, only passing flags the installed cosign actually supports.
COSIGN_SIGN_FLAGS := --yes --allow-http-registry \
	$(shell cosign sign --help 2>/dev/null | grep -q -- '--use-signing-config' && echo --use-signing-config=false) \
	$(shell cosign sign --help 2>/dev/null | grep -q -- '--new-bundle-format'  && echo --new-bundle-format=false) \
	$(shell cosign sign --help 2>/dev/null | grep -q -- '--tlog-upload'         && echo --tlog-upload=false)
COSIGN_VERIFY_FLAGS := --allow-http-registry \
	$(shell cosign verify --help 2>/dev/null | grep -q -- '--insecure-ignore-tlog' && echo --insecure-ignore-tlog=true)

.PHONY: build sbom scan sign verify push clean

build:
	docker build -f Dockerfile -t $(IMAGE) ..

sbom: build
	mkdir -p $(dir $(SBOM))
	syft scan $(IMAGE) -o json > $(SBOM)

scan: build
	trivy image --exit-code 1 --severity HIGH,CRITICAL $(IMAGE)

sign: build
	cosign sign $(COSIGN_SIGN_FLAGS) --key $(COSIGN_KEY) $(IMAGE)

verify:
	cosign verify $(COSIGN_VERIFY_FLAGS) --key $(COSIGN_PUB) $(IMAGE)

push: build
	docker push $(IMAGE)

clean:
	rm -f $(SBOM)
