# Changelog

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
