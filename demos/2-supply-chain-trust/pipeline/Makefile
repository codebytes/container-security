REGISTRY ?= ghcr.io/codebytes
IMAGE_NAME ?= guardian-demo-app
TAG ?= v0.1.0-secure
IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(TAG)
SBOM := ../attestations/sbom.json

.PHONY: build sbom scan sign verify push clean

build:
	docker build -f Dockerfile -t $(IMAGE) ..

sbom: build
	syft packages $(IMAGE) -o json > $(SBOM)

scan: build
	trivy image --exit-code 1 --severity HIGH,CRITICAL $(IMAGE)

sign: build
	cosign sign $(IMAGE)

verify:
	cosign verify $(IMAGE)

push: build
	docker push $(IMAGE)

clean:
	rm -f $(SBOM)
