IMGNAME = sdelrio/rpi-hostap
VERSION = $(shell grep "ENV VERSION" Dockerfile| awk 'NF>1{print $$NF}')
SUBNET  = 192.168.254.0
APADDR  = 192.168.254.1
PLATFORM ?= linux/amd64,linux/arm/v7,linux/arm64
.PHONY: all build test taglatest

all: build test

build:
	@docker build -t $(IMGNAME):$(VERSION) --rm . && echo Buildname: $(IMGNAME):$(VERSION)

build-multiarch:
	$(info Make: Building container images: $(IMGNAME):${VERSION})
	docker buildx build \
		--platform $(PLATFORM) \
		--progress=plain \
		--tag $(IMGNAME):$(VERSION) \
		.

build-multiarch-push:
	$(info Make: Building container images: $(IMGNAME):${VERSION})
	docker buildx build \
		--platform $(PLATFORM) \
		--progress=plain \
		--tag $(IMGNAME):$(VERSION) \
		--push \
		.

build-multiarch-push-latest:
	$(info Make: Building container images: $(IMGNAME):latest)
	docker buildx build \
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
	@docker ps -a |grep rpi-hostap |cut -f 1 -d' '|xargs -P1 -i docker stop {}
	@docker ps -a |grep rpi-hostap |cut -f 1 -d' '|xargs -P1 -i docker rm {}
	@docker rmi $(IMGNAME):$(VERSION)
taglatest:
	docker tag -f $(IMGNAME):$(VERSION) $(IMGNAME):lastest
	docker tag -f $(IMGNAME):$(VERSION) sdelrio/$(IMGNAME):$(VERSION)
	docker tag -f $(IMGNAME):$(VERSION) sdelrio/$(IMGNAME):latest
push:
	docker push sdelrio/$(IMGNAME)
	docker push sdelrio/$(IMGNAME):$(VERSION)
release: taglatest push
