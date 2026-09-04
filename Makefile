IMGNAME = sdelrio/rpi-hostap
VERSION = $(shell scripts/get-version.sh)
SUBNET  = 192.168.254.0
APADDR  = 192.168.254.1
PLATFORM ?= linux/amd64,linux/arm/v7,linux/arm64

OS := $(shell uname -s)

# Interface setup: ifconfig is deprecated on Linux, so use ip there.
# Keep ifconfig for macOS (Darwin), where ip is unavailable.
ifeq ($(OS),Darwin)
IF_DOWN = ifconfig wlan0 $(APADDR)/24 down
IF_UP = ifconfig wlan0 $(APADDR)/24 up
else
IF_DOWN = ip link set wlan0 down
IF_UP = ip addr add $(APADDR)/24 dev wlan0 2>/dev/null || true; ip link set wlan0 up
endif

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

.PHONY: all build test system-test taglatest prepare layer-check docs-build docs-dev docs-clean docs-check docs-links

all: build test

# Enforce the lib/ layering rule (issue #240): lib/core/ modules are pure
# and must not invoke system commands (iptables/ip/iw/sysctl/...) or touch
# /proc; all system interaction belongs in lib/sys/.
layer-check:
	@if grep -rEn '(^|[^[:alnum:]_/-])(iptables|ip6tables|iw|sysctl|hostapd_cli|dnsmasq|ifconfig|tc|nft)([^[:alnum:]_-]|$$)|/proc/' lib/core/ ; then \
		echo "FAIL: forbidden system command or /proc path in lib/core/" >&2 ; \
		exit 1 ; \
	else \
		echo "OK: no forbidden commands in lib/core/" ; \
	fi

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

docs-build:
	cd docs-site && npm ci && npm run build

docs-dev:
	cd docs-site && npm run dev

docs-clean:
	rm -rf docs-site/dist docs-site/.astro docs-site/src/content/docs

docs-check: docs-build
	@fail=0; \
	for f in $$(find docs-site/dist -name '*.html'); do \
		count=$$(grep -c '<h1' "$$f" || true); \
		if [ "$$count" -ne 1 ]; then \
			echo "FAIL: $$f has $$count <h1> tags (expected 1)" >&2; \
			fail=1; \
		fi; \
	done; \
	if [ "$$fail" -ne 0 ]; then \
		echo "docs-check: FAILED" >&2; \
		exit 1; \
	fi; \
	echo "docs-check: OK"

docs-links:
	@scripts/check-docs-links.sh

test:
	@sudo $(IF_DOWN)
	@sudo $(IF_UP)
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
# CI-oriented end-to-end system test (Linux only, needs mac80211_hwsim).
system-test:
ifeq ($(OS),Linux)
	sudo tests/system_test.sh
else
	@echo "system-test is Linux-only (GitHub runners); skipping on $(OS)"
endif

run:
	@sudo $(IF_DOWN)
	@sudo $(IF_UP)
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
	@sudo $(IF_DOWN)
	@sudo $(IF_UP)
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
