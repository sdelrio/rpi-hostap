# Changelog

## [0.41.0](https://github.com/sdelrio/rpi-hostap/compare/v0.40.0...v0.41.0) (2026-08-26)


### ✨ Features

* 802.11ax (HE) support via HE_ENABLED/HE_CAPAB ([#296](https://github.com/sdelrio/rpi-hostap/issues/296)) ([e095da1](https://github.com/sdelrio/rpi-hostap/commit/e095da1c7738ad0e8f19b8fe1438a9c5d1f18bac))
* clients.sh leases subcommand showing dnsmasq DHCP leases ([#297](https://github.com/sdelrio/rpi-hostap/issues/297)) ([a07fb21](https://github.com/sdelrio/rpi-hostap/commit/a07fb21df7836f77a628de04aa97c55051496bbf))
* fail healthcheck when HEALTHCHECK_MIN_STATIONS set but control interface missing ([#283](https://github.com/sdelrio/rpi-hostap/issues/283)) ([#300](https://github.com/sdelrio/rpi-hostap/issues/300)) ([fc0ddc0](https://github.com/sdelrio/rpi-hostap/commit/fc0ddc0d205253e17b630b1e25b78aefb00ab24f))
* wlanstart.sh --check runtime state audit ([#288](https://github.com/sdelrio/rpi-hostap/issues/288)) ([#294](https://github.com/sdelrio/rpi-hostap/issues/294)) ([c2ea720](https://github.com/sdelrio/rpi-hostap/commit/c2ea72074fed4efcd98c63635ca263a2b224329f))


### 🩹 Fixes

* check nat_apply_rules/ipv6_apply_rules exit status ([#279](https://github.com/sdelrio/rpi-hostap/issues/279)) ([#304](https://github.com/sdelrio/rpi-hostap/issues/304)) ([f3ff8d7](https://github.com/sdelrio/rpi-hostap/commit/f3ff8d7798fd838f3f5ec736a3d4e6ab899ce6cc))
* clients.sh reports error when hostapd_cli fails ([#281](https://github.com/sdelrio/rpi-hostap/issues/281)) ([#302](https://github.com/sdelrio/rpi-hostap/issues/302)) ([d6e9ee1](https://github.com/sdelrio/rpi-hostap/commit/d6e9ee13a741eaac19e87faea415bd40f0c78e0b))
* COUNTRY_CODE set-but-empty skips regulatory default warning ([#301](https://github.com/sdelrio/rpi-hostap/issues/301)) ([09f66b1](https://github.com/sdelrio/rpi-hostap/commit/09f66b139726232059779acfdd80b982af7af01f))
* deep healthcheck now honors CTRL_IFACE_DIR ([#280](https://github.com/sdelrio/rpi-hostap/issues/280)) ([#303](https://github.com/sdelrio/rpi-hostap/issues/303)) ([9cd5d1f](https://github.com/sdelrio/rpi-hostap/commit/9cd5d1f24c87c6b7d5036a4c0b7035524535965c))
* MAC_FILTER=2 denylist emits macaddr_acl=0 ([#278](https://github.com/sdelrio/rpi-hostap/issues/278)) ([#305](https://github.com/sdelrio/rpi-hostap/issues/305)) ([837904d](https://github.com/sdelrio/rpi-hostap/commit/837904dfca27143ca00e0b41b0e2e851f3a0344c))


### ♻️ Code Refactoring

* module-prefix private globals in lib/core/channel.sh ([#285](https://github.com/sdelrio/rpi-hostap/issues/285)) ([#298](https://github.com/sdelrio/rpi-hostap/issues/298)) ([6a927f0](https://github.com/sdelrio/rpi-hostap/commit/6a927f0343d665b55655e0ced8242d0d227b7a6d))

## [0.40.0](https://github.com/sdelrio/rpi-hostap/compare/v0.39.0...v0.40.0) (2026-08-26)


### ✨ Features

* **wpa:** add PMF (802.11w) toggle env var ([#235](https://github.com/sdelrio/rpi-hostap/issues/235)) ([#272](https://github.com/sdelrio/rpi-hostap/issues/272)) ([a891db1](https://github.com/sdelrio/rpi-hostap/commit/a891db1f3433e006521133ba9937f7256bbc7acc))


### 🩹 Fixes

* **docker:** pin libssl3/libcrypto3 in apk install ([#271](https://github.com/sdelrio/rpi-hostap/issues/271)) ([#273](https://github.com/sdelrio/rpi-hostap/issues/273)) ([5b7e943](https://github.com/sdelrio/rpi-hostap/commit/5b7e943e7e06fe9a4abba106ae923f8e43dea08a))
* upgrade alpine packages at image build to clear CVE-2026-14456 ([#267](https://github.com/sdelrio/rpi-hostap/issues/267)) ([55939d6](https://github.com/sdelrio/rpi-hostap/commit/55939d62b5cb91ca25323867237238cd16ef88e7))


### ♻️ Code Refactoring

* declarative module loading via lib/bootstrap.sh ([#269](https://github.com/sdelrio/rpi-hostap/issues/269)) ([0a16e33](https://github.com/sdelrio/rpi-hostap/commit/0a16e33e5338c0fbbcffc0e7596b4d6a5c0d5c0b)), closes [#239](https://github.com/sdelrio/rpi-hostap/issues/239)
* deduplicate env plumbing in clients.sh and healthcheck.sh ([#243](https://github.com/sdelrio/rpi-hostap/issues/243)) ([#262](https://github.com/sdelrio/rpi-hostap/issues/262)) ([417d2db](https://github.com/sdelrio/rpi-hostap/commit/417d2db02d61d4f2353c078e502eb514d3dd3a89))
* enforce &lt;module&gt;_&lt;verb&gt; naming convention across lib/ ([#264](https://github.com/sdelrio/rpi-hostap/issues/264)) ([f2aff80](https://github.com/sdelrio/rpi-hostap/commit/f2aff803aae54e8323fc8f5f3c779a88c79ac7cb))
* extract config emission from wlanstart.sh into lib/core modules ([#270](https://github.com/sdelrio/rpi-hostap/issues/270)) ([1b4cee4](https://github.com/sdelrio/rpi-hostap/commit/1b4cee4df73440031b6f215b668e374a8111eace))
* phase-based lifecycle with registered setup/teardown hooks ([#265](https://github.com/sdelrio/rpi-hostap/issues/265)) ([a780aa4](https://github.com/sdelrio/rpi-hostap/commit/a780aa4863fc9524cbac20293b0caaf490f2d118))
* split lib/ into core/ (pure) and sys/ (effectful) layers ([#268](https://github.com/sdelrio/rpi-hostap/issues/268)) ([04b8ae8](https://github.com/sdelrio/rpi-hostap/commit/04b8ae8a8331720ac28cd588d83dbecdb192eb10)), closes [#240](https://github.com/sdelrio/rpi-hostap/issues/240)

## [0.39.0](https://github.com/sdelrio/rpi-hostap/compare/v0.38.0...v0.39.0) (2026-08-26)


### ✨ Features

* **clients:** station count command and optional min-stations healthcheck ([#247](https://github.com/sdelrio/rpi-hostap/issues/247)) ([29257e4](https://github.com/sdelrio/rpi-hostap/commit/29257e4cf029e1ac5aae3a0fd5742b1e350dbbac)), closes [#234](https://github.com/sdelrio/rpi-hostap/issues/234)
* **nat:** validate OUTGOINGS interfaces exist before applying rules ([#227](https://github.com/sdelrio/rpi-hostap/issues/227)) ([#253](https://github.com/sdelrio/rpi-hostap/issues/253)) ([c8c57aa](https://github.com/sdelrio/rpi-hostap/commit/c8c57aa2f304c067dd06a84fa9abca05c2bc0fa2))
* **radio:** add TX_POWER env var for transmit power control ([#236](https://github.com/sdelrio/rpi-hostap/issues/236)) ([#246](https://github.com/sdelrio/rpi-hostap/issues/246)) ([f5c0422](https://github.com/sdelrio/rpi-hostap/commit/f5c04223c8bc41dc6ca11e5e9445f8e0c4e3cfec))
* **secrets:** add SSID_FILE and WPA_PASSPHRASE_FILE inputs ([#232](https://github.com/sdelrio/rpi-hostap/issues/232)) ([#248](https://github.com/sdelrio/rpi-hostap/issues/248)) ([d670759](https://github.com/sdelrio/rpi-hostap/commit/d670759b8844855890922d28d72e18ab1f21901e))


### 🩹 Fixes

* **channel:** normalize COUNTRY_CODE / HW_MODE case before validation ([#222](https://github.com/sdelrio/rpi-hostap/issues/222)) ([#258](https://github.com/sdelrio/rpi-hostap/issues/258)) ([7095777](https://github.com/sdelrio/rpi-hostap/commit/7095777267e117c677ae17adbd53652ded398a6c))
* **channel:** validate 5 GHz channels against COUNTRY_CODE ([#221](https://github.com/sdelrio/rpi-hostap/issues/221)) ([#259](https://github.com/sdelrio/rpi-hostap/issues/259)) ([ed2ad8f](https://github.com/sdelrio/rpi-hostap/commit/ed2ad8f7410abac4620a42816c9a542265104410))
* **dhcp:** add bind-dynamic to avoid host DHCP conflicts ([#223](https://github.com/sdelrio/rpi-hostap/issues/223)) ([#257](https://github.com/sdelrio/rpi-hostap/issues/257)) ([1f557d5](https://github.com/sdelrio/rpi-hostap/commit/1f557d55b5dde52499c1260306d8b909371fce91))
* healthcheck passes forever when started-time file is missing ([#261](https://github.com/sdelrio/rpi-hostap/issues/261)) ([9fad925](https://github.com/sdelrio/rpi-hostap/commit/9fad925c27b93a38c4bc7d8b2c9ede9ef07fd47a))
* **ipv6:** handle sysctl failure in enable_ipv6_forwarding gracefully ([#225](https://github.com/sdelrio/rpi-hostap/issues/225)) ([#255](https://github.com/sdelrio/rpi-hostap/issues/255)) ([9202fdf](https://github.com/sdelrio/rpi-hostap/commit/9202fdf24eedf03d4fcd298de6abe4b4feba6c02))
* use iptables probe for privileged-mode check ([#228](https://github.com/sdelrio/rpi-hostap/issues/228)) ([#252](https://github.com/sdelrio/rpi-hostap/issues/252)) ([6521fbc](https://github.com/sdelrio/rpi-hostap/commit/6521fbc0eae350648167aefc3040cb15ab60267e))
* **wpa:** emit ieee80211w PMF for WPA3-SAE and mixed mode ([#220](https://github.com/sdelrio/rpi-hostap/issues/220)) ([#260](https://github.com/sdelrio/rpi-hostap/issues/260)) ([f29d1cc](https://github.com/sdelrio/rpi-hostap/commit/f29d1ccf9d361f831a6e488b5103136c130b4058))


### ♻️ Code Refactoring

* **channel:** emit informational warnings at most once per run ([#231](https://github.com/sdelrio/rpi-hostap/issues/231)) ([#249](https://github.com/sdelrio/rpi-hostap/issues/249)) ([1d9bd7a](https://github.com/sdelrio/rpi-hostap/commit/1d9bd7ac9648bbb2c27250d5117977ec9434bb9d))
* **dhcp:** compute DHCP range once per startup ([#224](https://github.com/sdelrio/rpi-hostap/issues/224)) ([#256](https://github.com/sdelrio/rpi-hostap/issues/256)) ([a8c5f11](https://github.com/sdelrio/rpi-hostap/commit/a8c5f116cdd4dd3a869c42c782748f256470ea94))
* **env:** centralize environment defaults into lib/env.sh ([#237](https://github.com/sdelrio/rpi-hostap/issues/237)) ([#244](https://github.com/sdelrio/rpi-hostap/issues/244)) ([f928f04](https://github.com/sdelrio/rpi-hostap/commit/f928f0486c9f79a43ca406e3f4990e37f844ca06))

## [0.38.0](https://github.com/sdelrio/rpi-hostap/compare/v0.37.0...v0.38.0) (2026-08-25)


### ✨ Features

* **channel:** support CHANNEL=acs automatic channel selection ([#203](https://github.com/sdelrio/rpi-hostap/issues/203)) ([4105bcf](https://github.com/sdelrio/rpi-hostap/commit/4105bcf6fd35e240e57aed10361bb4be3572c8e5))
* **clients:** add --json machine-readable station output ([#202](https://github.com/sdelrio/rpi-hostap/issues/202)) ([9258831](https://github.com/sdelrio/rpi-hostap/commit/9258831acb94bff5ec0d40f35b188db67502cb67)), closes [#198](https://github.com/sdelrio/rpi-hostap/issues/198)
* **dhcp:** validate AP_ADDR lies inside SUBNET/mask ([#211](https://github.com/sdelrio/rpi-hostap/issues/211)) ([1bcb6a8](https://github.com/sdelrio/rpi-hostap/commit/1bcb6a83371d5677247e71553c020ad06bcd385e)), closes [#189](https://github.com/sdelrio/rpi-hostap/issues/189)
* **dhcp:** validate DHCP range order, subnet bounds and AP overlap ([#210](https://github.com/sdelrio/rpi-hostap/issues/210)) ([df14903](https://github.com/sdelrio/rpi-hostap/commit/df14903dfbd1522a468723bebb45f5f1da3065fb)), closes [#190](https://github.com/sdelrio/rpi-hostap/issues/190)
* **hostapd:** HOSTAPD_EXTRA_OPTS passthrough for extra config lines ([#204](https://github.com/sdelrio/rpi-hostap/issues/204)) ([5759ed6](https://github.com/sdelrio/rpi-hostap/commit/5759ed60e0c20bb6c253ffd578f9e7831b79935e))
* **logging:** retain timestamped failure logs with rotation ([#199](https://github.com/sdelrio/rpi-hostap/issues/199)) ([#200](https://github.com/sdelrio/rpi-hostap/issues/200)) ([9ac178a](https://github.com/sdelrio/rpi-hostap/commit/9ac178a240b8ce5eea9209d44310bbb844e167bc))


### 🩹 Fixes

* **channel:** allow channel 14 only for JP + hw_mode=b ([#207](https://github.com/sdelrio/rpi-hostap/issues/207)) ([714bdab](https://github.com/sdelrio/rpi-hostap/commit/714bdabc23df6dc6020dd77d53a9cfcca0330da9)), closes [#193](https://github.com/sdelrio/rpi-hostap/issues/193)
* **config:** require HW_MODE=a when VHT_ENABLED is set ([#209](https://github.com/sdelrio/rpi-hostap/issues/209)) ([2e70381](https://github.com/sdelrio/rpi-hostap/commit/2e70381a12b380b67fa6a1eb542d01fbb6f8335c)), closes [#191](https://github.com/sdelrio/rpi-hostap/issues/191)
* **healthcheck:** explicit error when HEALTHCHECK_DEEP lacks INTERFACE ([#215](https://github.com/sdelrio/rpi-hostap/issues/215)) ([1b4733f](https://github.com/sdelrio/rpi-hostap/commit/1b4733f72b6cfef2b5d587eec3625d022a8e8ee0))
* **healthcheck:** guard HEALTHCHECK_START_PERIOD against non-numeric values ([#208](https://github.com/sdelrio/rpi-hostap/issues/208)) ([8b8b199](https://github.com/sdelrio/rpi-hostap/commit/8b8b19931da48ed18ffc23f7c112e9910cad0c4a)), closes [#192](https://github.com/sdelrio/rpi-hostap/issues/192)
* **interface:** teardown removes only configured AP_ADDR, not all addresses ([#188](https://github.com/sdelrio/rpi-hostap/issues/188)) ([#212](https://github.com/sdelrio/rpi-hostap/issues/212)) ([636e76e](https://github.com/sdelrio/rpi-hostap/commit/636e76e000a308f6ab78fab28c4150cefcdb713b))
* **security:** prevent config injection via WPA_PASSPHRASE/PRI_DNS/SEC_DNS ([#216](https://github.com/sdelrio/rpi-hostap/issues/216)) ([91b08d1](https://github.com/sdelrio/rpi-hostap/commit/91b08d1f9635ae4418fcc0d2b6e651fddcbb034a)), closes [#184](https://github.com/sdelrio/rpi-hostap/issues/184)
* **signals:** defer teardown until multirun children have exited ([#217](https://github.com/sdelrio/rpi-hostap/issues/217)) ([bb1b032](https://github.com/sdelrio/rpi-hostap/commit/bb1b0323fdfd6ba23e997106ba54c594f0d6ed1c)), closes [#183](https://github.com/sdelrio/rpi-hostap/issues/183)
* **stations:** make invalid MAX_STATIONS fatal at validation ([#213](https://github.com/sdelrio/rpi-hostap/issues/213)) ([991271a](https://github.com/sdelrio/rpi-hostap/commit/991271a7dac0bac096d256c67b10de71529430cb)), closes [#187](https://github.com/sdelrio/rpi-hostap/issues/187)


### ♻️ Code Refactoring

* **scripts:** invoke get-version.sh with bash consistently ([#205](https://github.com/sdelrio/rpi-hostap/issues/205)) ([2e6158c](https://github.com/sdelrio/rpi-hostap/commit/2e6158c376f568189992c3a6ebdac91f3b02c82c)), closes [#195](https://github.com/sdelrio/rpi-hostap/issues/195)

## [0.37.0](https://github.com/sdelrio/rpi-hostap/compare/v0.36.0...v0.37.0) (2026-08-25)


### ✨ Features

* add --version flag to wlanstart.sh ([#178](https://github.com/sdelrio/rpi-hostap/issues/178)) ([33984f1](https://github.com/sdelrio/rpi-hostap/commit/33984f1c3779c5cf74d93287bcf7c9557e6cd880))
* add leveled logging library ([#181](https://github.com/sdelrio/rpi-hostap/issues/181)) ([474efd2](https://github.com/sdelrio/rpi-hostap/commit/474efd205a9f86e781cd79f0279ee395f7360bdd))
* **clients:** add deauth subcommand ([#166](https://github.com/sdelrio/rpi-hostap/issues/166)) ([#180](https://github.com/sdelrio/rpi-hostap/issues/180)) ([1b4cb29](https://github.com/sdelrio/rpi-hostap/commit/1b4cb2980a2db9792494da2d5d963e03d082967d))
* reject unknown HW_MODE in validate mode ([#163](https://github.com/sdelrio/rpi-hostap/issues/163)) ([#176](https://github.com/sdelrio/rpi-hostap/issues/176)) ([2866361](https://github.com/sdelrio/rpi-hostap/commit/2866361d433a05ba504e123187615452301c9552))
* retain daemon failure log on non-zero exit ([#175](https://github.com/sdelrio/rpi-hostap/issues/175)) ([122fdd6](https://github.com/sdelrio/rpi-hostap/commit/122fdd65e87d5e3315acd4203ec278ed6e45249d))
* support configurable subnet mask ([#165](https://github.com/sdelrio/rpi-hostap/issues/165)) ([#179](https://github.com/sdelrio/rpi-hostap/issues/179)) ([e9dfea0](https://github.com/sdelrio/rpi-hostap/commit/e9dfea0997ed9faf92210594805e451e10b37f48))


### 🩹 Fixes

* generate configs atomically via temp file ([#173](https://github.com/sdelrio/rpi-hostap/issues/173)) ([8f707f7](https://github.com/sdelrio/rpi-hostap/commit/8f707f745154b166374fbb792078f0dd6a3781ba))
* handle missing/non-numeric sysctl in nat setup ([#174](https://github.com/sdelrio/rpi-hostap/issues/174)) ([74ab1c2](https://github.com/sdelrio/rpi-hostap/commit/74ab1c25210920e5e036f232290fea218c4748ad))
* make ipv6 rule functions self-contained ([#159](https://github.com/sdelrio/rpi-hostap/issues/159)) ([#171](https://github.com/sdelrio/rpi-hostap/issues/171)) ([e95da21](https://github.com/sdelrio/rpi-hostap/commit/e95da2109efcee3a9b00fa25af7cbcd18c829cb6))

## [0.36.0](https://github.com/sdelrio/rpi-hostap/compare/v0.35.0...v0.36.0) (2026-08-25)


### ✨ Features

* **clients:** clear error when control interface disabled ([#161](https://github.com/sdelrio/rpi-hostap/issues/161)) ([#169](https://github.com/sdelrio/rpi-hostap/issues/169)) ([737838b](https://github.com/sdelrio/rpi-hostap/commit/737838b3967c8780d43d8d2d78ca23b6fe002c86))
* **clients:** opt-in ctrl_interface and clients.sh for listing connected stations ([#134](https://github.com/sdelrio/rpi-hostap/issues/134)) ([925eec9](https://github.com/sdelrio/rpi-hostap/commit/925eec92b616707046b7c99a1f6febba3d2ef309))
* **entrypoint:** add --validate dry-run mode with CI env matrix ([#135](https://github.com/sdelrio/rpi-hostap/issues/135)) ([6afcec1](https://github.com/sdelrio/rpi-hostap/commit/6afcec1510f85859b7181351f07a90febd437d5c))
* **healthcheck:** add opt-in deep AP beacon check via hostapd_cli ([#123](https://github.com/sdelrio/rpi-hostap/issues/123)) ([#136](https://github.com/sdelrio/rpi-hostap/issues/136)) ([f4877b9](https://github.com/sdelrio/rpi-hostap/commit/f4877b9d6e4a5380112d93077ed5fac84d71a486))
* **logging:** tag daemon output and report failing service on multirun exit ([#119](https://github.com/sdelrio/rpi-hostap/issues/119)) ([#133](https://github.com/sdelrio/rpi-hostap/issues/133)) ([72d19ca](https://github.com/sdelrio/rpi-hostap/commit/72d19ca69402adccbc0e70b9bb6b4415f7b847d1))


### 🩹 Fixes

* **dhcp:** validate DHCP_RANGE fields and SUBNET instead of comma-count only ([#113](https://github.com/sdelrio/rpi-hostap/issues/113)) ([#128](https://github.com/sdelrio/rpi-hostap/issues/128)) ([d032fa7](https://github.com/sdelrio/rpi-hostap/commit/d032fa7509e8f945f1d987e81ee9147b803ee126))
* **entrypoint:** handle signals received before multirun starts ([#125](https://github.com/sdelrio/rpi-hostap/issues/125)) ([ba15dea](https://github.com/sdelrio/rpi-hostap/commit/ba15deaa2f5de26337be58f60781f92bf2f1e9c3))
* **entrypoint:** validate AP_ADDR/SUBNET and abort on IP setup failure ([#114](https://github.com/sdelrio/rpi-hostap/issues/114)) ([#127](https://github.com/sdelrio/rpi-hostap/issues/127)) ([532d34e](https://github.com/sdelrio/rpi-hostap/commit/532d34e159a89a076e9469f6fcaf37fab3928aa6))
* **healthcheck:** anchor IP match and require interface state UP ([#112](https://github.com/sdelrio/rpi-hostap/issues/112)) ([#129](https://github.com/sdelrio/rpi-hostap/issues/129)) ([c63012b](https://github.com/sdelrio/rpi-hostap/commit/c63012b63d6517c8764cda10f27e791652e3df2a))
* **healthcheck:** measure grace period from container start time, not host uptime ([#111](https://github.com/sdelrio/rpi-hostap/issues/111)) ([#130](https://github.com/sdelrio/rpi-hostap/issues/130)) ([56f0d33](https://github.com/sdelrio/rpi-hostap/commit/56f0d33f7948a805275cdc6bda98f1fd55e81177))
* **mac_filter:** make disabled path a silent no-op returning success ([#116](https://github.com/sdelrio/rpi-hostap/issues/116)) ([#131](https://github.com/sdelrio/rpi-hostap/issues/131)) ([ccf01a5](https://github.com/sdelrio/rpi-hostap/commit/ccf01a527748936828c03144b1334c37b4042cc4))
* validate SSID before writing hostapd.conf ([#170](https://github.com/sdelrio/rpi-hostap/issues/170)) ([a4fdafb](https://github.com/sdelrio/rpi-hostap/commit/a4fdafbff898d880932a1edc9287d499c752a7a0))


### ♻️ Code Refactoring

* **entrypoint:** extract NAT/interface logic into lib/nat.sh and lib/interface.sh ([#132](https://github.com/sdelrio/rpi-hostap/issues/132)) ([c2c996b](https://github.com/sdelrio/rpi-hostap/commit/c2c996bd00f385b71c734f7c34cb592d9147b943))
* **healthcheck:** add set -euo pipefail strict mode ([#154](https://github.com/sdelrio/rpi-hostap/issues/154)) ([2a6bcbc](https://github.com/sdelrio/rpi-hostap/commit/2a6bcbcafee729ae0f158639ea2cf4fba1a40391)), closes [#151](https://github.com/sdelrio/rpi-hostap/issues/151)
* **lib:** add missing shellcheck source/shell directives ([#155](https://github.com/sdelrio/rpi-hostap/issues/155)) ([dc47633](https://github.com/sdelrio/rpi-hostap/commit/dc4763334538544e2b2fc4fcccd5a30dadd7b28a)), closes [#152](https://github.com/sdelrio/rpi-hostap/issues/152)
* **scripts:** apply shellcheck style-level cleanups ([#156](https://github.com/sdelrio/rpi-hostap/issues/156)) ([447f27a](https://github.com/sdelrio/rpi-hostap/commit/447f27aa14a1eb3076f8117c0081537ea7ac9e47)), closes [#153](https://github.com/sdelrio/rpi-hostap/issues/153)

## [0.35.0](https://github.com/sdelrio/rpi-hostap/compare/v0.34.0...v0.35.0) (2026-08-24)


### ✨ Features

* **channel:** validate 5GHz channels for hw_mode=a with DFS warning ([#89](https://github.com/sdelrio/rpi-hostap/issues/89)) ([#99](https://github.com/sdelrio/rpi-hostap/issues/99)) ([a91d928](https://github.com/sdelrio/rpi-hostap/commit/a91d928e99887e9b4407cd0ea82bee0af3abdd40))
* **healthcheck:** verify AP IP assigned to interface ([#105](https://github.com/sdelrio/rpi-hostap/issues/105)) ([66d241d](https://github.com/sdelrio/rpi-hostap/commit/66d241dd01a26439af0fdbbc36edc78f9bc9114a)), closes [#91](https://github.com/sdelrio/rpi-hostap/issues/91)
* MAC address filtering (allowlist/denylist) ([#103](https://github.com/sdelrio/rpi-hostap/issues/103)) ([4da0787](https://github.com/sdelrio/rpi-hostap/commit/4da07879bad3890e775ba8736ce01a03a19a612f)), closes [#93](https://github.com/sdelrio/rpi-hostap/issues/93)
* optional IPv6 support (RA/DHCPv6 via dnsmasq) ([#102](https://github.com/sdelrio/rpi-hostap/issues/102)) ([c8667ab](https://github.com/sdelrio/rpi-hostap/commit/c8667abd0ef4c788e43d91fcdab0d4e3d2ee02fc)), closes [#94](https://github.com/sdelrio/rpi-hostap/issues/94)
* **tests:** end-to-end system test with mac80211_hwsim ([#108](https://github.com/sdelrio/rpi-hostap/issues/108)) ([7830f5e](https://github.com/sdelrio/rpi-hostap/commit/7830f5e00ac7e2c27ebf9dee8aa971e4b2328f9e))
* use multirun to manage hostapd/dnsmasq processes ([#106](https://github.com/sdelrio/rpi-hostap/issues/106)) ([3204bd6](https://github.com/sdelrio/rpi-hostap/commit/3204bd6fdfbc80393783af4e3711d954cc78118a))


### 🩹 Fixes

* flush interface address and bring link down in cleanup() ([#88](https://github.com/sdelrio/rpi-hostap/issues/88)) ([#100](https://github.com/sdelrio/rpi-hostap/issues/100)) ([d74fbd7](https://github.com/sdelrio/rpi-hostap/commit/d74fbd750bcfef0cebdcec1238746c8622a84d3a))
* validate WPA_PASSPHRASE length (8-63 chars) before starting daemons ([#97](https://github.com/sdelrio/rpi-hostap/issues/97)) ([6bd6c01](https://github.com/sdelrio/rpi-hostap/commit/6bd6c01ceec34809635be275576e406206924d06)), closes [#90](https://github.com/sdelrio/rpi-hostap/issues/90)

## [0.34.0](https://github.com/sdelrio/rpi-hostap/compare/v0.33.0...v0.34.0) (2026-08-22)


### ✨ Features

* add AP_ISOLATION env var to isolate wireless clients ([#56](https://github.com/sdelrio/rpi-hostap/issues/56)) ([201ede0](https://github.com/sdelrio/rpi-hostap/commit/201ede07082a489bd71f94682cc8bb0830a383e0))
* add HEALTHCHECK to Dockerfile ([#36](https://github.com/sdelrio/rpi-hostap/issues/36)) ([#60](https://github.com/sdelrio/rpi-hostap/issues/60)) ([a1296c4](https://github.com/sdelrio/rpi-hostap/commit/a1296c4a7b32d8c596ee9829d8164521293d90ce))
* add HIDE_SSID env var to suppress SSID broadcast ([#55](https://github.com/sdelrio/rpi-hostap/issues/55)) ([0c4b424](https://github.com/sdelrio/rpi-hostap/commit/0c4b4245b01d185c87bb8bd165e137c4b55ca8d2)), closes [#32](https://github.com/sdelrio/rpi-hostap/issues/32)
* add MAX_STATIONS env var to limit connected clients ([#54](https://github.com/sdelrio/rpi-hostap/issues/54)) ([691970d](https://github.com/sdelrio/rpi-hostap/commit/691970d158e05ff0b0ac3a1dc5008ab186c151b8))
* region-aware channel validation with COUNTRY_CODE (default EU) ([#68](https://github.com/sdelrio/rpi-hostap/issues/68)) ([df5cee6](https://github.com/sdelrio/rpi-hostap/commit/df5cee660a5f9299fe72a9915246584c8ff566db))
* validate CHANNEL against HW_MODE ([#38](https://github.com/sdelrio/rpi-hostap/issues/38)) ([#58](https://github.com/sdelrio/rpi-hostap/issues/58)) ([ed21c27](https://github.com/sdelrio/rpi-hostap/commit/ed21c27573bcc65b1ea93b11eebfa785df3ced34))
* **wpa:** add WPA3/SAE support via WPA_VERSION env var ([#74](https://github.com/sdelrio/rpi-hostap/issues/74)) ([15f1ab8](https://github.com/sdelrio/rpi-hostap/commit/15f1ab8568300d7e05d0f919c827f9ccd302566b))


### 🩹 Fixes

* always regenerate /etc/hostapd.conf so env var changes apply ([#62](https://github.com/sdelrio/rpi-hostap/issues/62)) ([#67](https://github.com/sdelrio/rpi-hostap/issues/67)) ([ca571fc](https://github.com/sdelrio/rpi-hostap/commit/ca571fc937c85bc9b5fb951e6438e7e5968d2e01))
* correct 'Througput' typo in wlanstart.sh comments ([#66](https://github.com/sdelrio/rpi-hostap/issues/66)) ([8d2c81f](https://github.com/sdelrio/rpi-hostap/commit/8d2c81f3a152b3b8e20f97d245d210465eea1e75))
* quote remaining expansions and use arrays for OUTGOINGS parsing ([#72](https://github.com/sdelrio/rpi-hostap/issues/72)) ([07d4d7d](https://github.com/sdelrio/rpi-hostap/commit/07d4d7d90d55f8ecd7cbb758ed49b9a520f05265))
* replace deprecated ifconfig with ip commands on Linux ([#51](https://github.com/sdelrio/rpi-hostap/issues/51)) ([585dc4e](https://github.com/sdelrio/rpi-hostap/commit/585dc4ee258ac56c8d765fafabf967384ecd3640)), closes [#28](https://github.com/sdelrio/rpi-hostap/issues/28)
* sync Dockerfile VERSION with release-please manifest ([#70](https://github.com/sdelrio/rpi-hostap/issues/70)) ([6c50cda](https://github.com/sdelrio/rpi-hostap/commit/6c50cdab2f7b84f76830dbc751badd0e8063e710))
* **wlanstart:** add bats tests for graceful shutdown cleanup ([50c6043](https://github.com/sdelrio/rpi-hostap/commit/50c60432541d353aaec33a406a35f3b63a0a87d8))
* **wlanstart:** add graceful shutdown with proper daemon cleanup ([bfbed79](https://github.com/sdelrio/rpi-hostap/commit/bfbed79ccccecdf0d2a3f45cc7393e1259554708)), closes [#37](https://github.com/sdelrio/rpi-hostap/issues/37)


### ♻️ Code Refactoring

* extract AP_ISOLATION logic to shared lib ([#82](https://github.com/sdelrio/rpi-hostap/issues/82)) ([0d824f0](https://github.com/sdelrio/rpi-hostap/commit/0d824f042424f50774663571671abf2e404f42f7))
* extract channel validation to shared lib/channel.sh ([#86](https://github.com/sdelrio/rpi-hostap/issues/86)) ([ab13c0b](https://github.com/sdelrio/rpi-hostap/commit/ab13c0bb5ccd154a8735ef355c1ec8ee7e227f90))
* extract default-credential warnings to shared lib/warnings.sh ([#80](https://github.com/sdelrio/rpi-hostap/issues/80)) ([#81](https://github.com/sdelrio/rpi-hostap/issues/81)) ([7b9cad7](https://github.com/sdelrio/rpi-hostap/commit/7b9cad75fbc612325f5ffcc9ae3452559a9d239e))
* extract DHCP_RANGE logic to shared lib/dhcp.sh (fixes [#76](https://github.com/sdelrio/rpi-hostap/issues/76)) ([#85](https://github.com/sdelrio/rpi-hostap/issues/85)) ([508e4a8](https://github.com/sdelrio/rpi-hostap/commit/508e4a8546d703bcd0893e4edafed233e9ca91da))
* extract HIDE_SSID logic to shared lib/ssid_hidden.sh ([#83](https://github.com/sdelrio/rpi-hostap/issues/83)) ([ea2e373](https://github.com/sdelrio/rpi-hostap/commit/ea2e3737b2b6eb084cd35980cbf883ec990e33de)), closes [#78](https://github.com/sdelrio/rpi-hostap/issues/78)
* extract MAX_STATIONS logic to shared lib/stations.sh ([#77](https://github.com/sdelrio/rpi-hostap/issues/77)) ([#84](https://github.com/sdelrio/rpi-hostap/issues/84)) ([ba76302](https://github.com/sdelrio/rpi-hostap/commit/ba76302dab8ce07576f72621b0b37086e9e69369))
* replace 'true ${VAR:=x}' idiom with ': "${VAR:=x}"' ([#73](https://github.com/sdelrio/rpi-hostap/issues/73)) ([36ae37f](https://github.com/sdelrio/rpi-hostap/commit/36ae37f167fd0bc2178c67513c454cfa154e9e09))

## [0.33.0](https://github.com/sdelrio/rpi-hostap/compare/v0.32.0...v0.33.0) (2026-08-21)


### Features

* add DHCP_RANGE env var for explicit control ([#40](https://github.com/sdelrio/rpi-hostap/issues/40)) ([#47](https://github.com/sdelrio/rpi-hostap/issues/47)) ([6738670](https://github.com/sdelrio/rpi-hostap/commit/6738670cf3cbaf736020f37b5d5ab97046fb5b9c))


### Bug Fixes

* add exit-on-error for dnsmasq and hostapd startup ([#49](https://github.com/sdelrio/rpi-hostap/issues/49)) ([00f8405](https://github.com/sdelrio/rpi-hostap/commit/00f84054143243c2e86571859772f823de5bde97)), closes [#30](https://github.com/sdelrio/rpi-hostap/issues/30)
* use DOCKERHUB_USER secret name ([a497462](https://github.com/sdelrio/rpi-hostap/commit/a497462c7b8e2817c178099b16f13b429e6cf84a))

## [0.32.0](https://github.com/sdelrio/rpi-hostap/compare/v0.31.0...v0.32.0) (2026-08-09)


### Features

* modernize stack - alpine 3.24, dnsmasq, GitHub Actions, release-please ([77b5fd6](https://github.com/sdelrio/rpi-hostap/commit/77b5fd65b9c5a51140b651a37e222d96586af6ae))
* modernize stack - alpine 3.24, dnsmasq, GitHub Actions, release-please ([40c96e4](https://github.com/sdelrio/rpi-hostap/commit/40c96e42191b8ec0179365d5957fe314cff1fbce))


### Bug Fixes

* change release-please type from docker to simple ([6f9ac70](https://github.com/sdelrio/rpi-hostap/commit/6f9ac70ab48c0bcb4a38e1e739f91dd974202dc6))
