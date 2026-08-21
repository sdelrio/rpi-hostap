IMGNAME = sdelrio/rpi-hostap
VERSION = $(shell grep "ENV VERSION" Dockerfile | awk -F= '{print $$NF}')
SUBNET  = 192.168.254.0
APADDR  = 192.168.254.1
PLATFORM ?= linux/amd64,linux/arm/v7,linux/arm64

OS := $(shell uname -s)
ifeq ($(OS),Darwin)
  ifneq (,$(shell command -v podman 2>/dev/null))
    PODMAN_SOCKET := $(shell podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null)
    ifneq ($(PODMAN_SOCKET),)
      export DOCKER_HOST = unix://$(PODMAN_SOCKET)
    endif
  endif
endif

# Detect build tool: prefer docker buildx, fallback to podman
HAS_BUILDX := $(shell docker buildx version >/dev/null 2>&1 && echo 1)
ifdef HAS_BUILDX
  BUILDER = docker buildx
else ifneq (,$(shell command -v podman 2>/dev/null))
  BUILDER = podman
else
  BUILDER = $(error Neither docker buildx nor podman found)
endif

.PHONY: all build test taglatest prepare

all: build test

prepare:
ifeq ($(OS),Darwin)
	@if command -v podman >/dev/null 2>&1; then \
		if podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' >/dev/null 2>&1; then \
			echo "Docker host set to Podman socket"; \
		fi; \
	fi
endif

build:
	@$(BUILDER) build -t $(IMGNAME):$(VERSION) --rm . && echo Buildname: $(IMGNAME):$(VERSION)

build-multiarch:
	$(info Make: Building container images: $(IMGNAME):${VERSION})
	$(BUILDER) build \
		--platform $(PLATFORM) \
		--progress=plain \
		--tag $(IMGNAME):$(VERSION) \
		.

build-multiarch-push:
	$(info Make: Building container images: $(IMGNAME):${VERSION})
	$(BUILDER) build \
		--platform $(PLATFORM) \
		--progress=plain \
		--tag $(IMGNAME):$(VERSION) \
		--push \
		.

build-multiarch-push-latest:
	$(info Make: Building container images: $(IMGNAME):latest)
	$(BUILDER) build \
		--platform $(PLATFORM) \
		--progress=plain \
		--tag $(IMGNAME):latest \
		--push \
		.

test:
	@sudo /sbin/ifconfig wlan0 $(APADDR)/24 down
	@sudo /sbin/ifconfig wlan0 $(APADDR)/24 up
	sudo docker run -t \
        --name $(IMGNAME)_test \
	-e INTERFACE=wlan0 \
	-e SSID=testssid \
	-e AP_ADDR=$(APADDR) \
	-e SUBNET=$(SUBNET) \
	-e SSID=testssid \
	-e CHANNEL=6 \
	-e WPA_PASSPHRASE=passw0rd \
	-e OUTGOINGS=eth0 \
        --entrypoint=/bin/test.sh \
	--privileged \
	--net host \
	--rm \
	$(IMGNAME):$(VERSION) \
        /bin/test.sh || sudo docker stop $(IMGNAME)_test && docker rm $(IMGNAME)_test
run:
	@sudo /sbin/ifconfig wlan0 $(APADDR)/24 down
	@sudo /sbin/ifconfig wlan0 $(APADDR)/24 up
	sudo docker run -d -t \
        --name $(IMGNAME)_run \
	-e INTERFACE=wlan0 \
	-e CHANNEL=6 \
	-e SSID=runssid \
	-e AP_ADDR=$(APADDR) \
	-e SUBNET=$(SUBNET) \
	-e WPA_PASSPHRASE=passw0rd \
	-e OUTGOINGS=eth0 \
	--privileged \
	--net host \
	$(IMGNAME):$(VERSION)
stop:
	@docker stop $(IMGNAME)_test || docker stop $(IMGNAME)_run || docker stop $(IMGNAME)_shell
	@docker rm $(IMGNAME)_test || docker rm $(IMGNAME)_run || docker rm $(IMGNAME)_shell
shell:
	@sudo /sbin/ifconfig wlan0 $(APADDR)/24 down
	@sudo /sbin/ifconfig wlan0 $(APADDR)/24 up
	@sudo docker run -t \
        --name $(IMGNAME)_shell \
	-e INTERFACE=wlan0 \
	-e SSID=shellssid \
	-e AP_ADDR=$(APADDR) \
	-e SUBNET=$(SUBNET) \
	-e WPA_PASSPHRASE=passw0rd \
	-e OUTGOINGS=eth0 \
	--privileged \
	--net host \
        -ti --entrypoint=/bin/sh \
	--rm \
	$(IMGNAME):$(VERSION) || sudo docker stop $(IMGNAME)_shell && docker rm $(IMGNAME)_shell
clean:
	@docker ps -a --filter "name=rpi-hostap" -q | xargs -r docker rm -f 2>/dev/null || true
	@docker rmi $(IMGNAME):$(VERSION) 2>/dev/null || true
taglatest:
	docker tag $(IMGNAME):$(VERSION) $(IMGNAME):latest
	docker tag $(IMGNAME):$(VERSION) sdelrio/$(IMGNAME):$(VERSION)
	docker tag $(IMGNAME):$(VERSION) sdelrio/$(IMGNAME):latest
push:
	docker push sdelrio/$(IMGNAME)
	docker push sdelrio/$(IMGNAME):$(VERSION)
release: taglatest push
