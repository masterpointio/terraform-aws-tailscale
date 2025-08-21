# Changelog

## [1.9.0](https://github.com/masterpointio/terraform-aws-tailscale/compare/v1.8.0...v1.9.0) (2025-08-21)


### Features

* add basic tests for local variables ([#65](https://github.com/masterpointio/terraform-aws-tailscale/issues/65)) ([75fd25c](https://github.com/masterpointio/terraform-aws-tailscale/commit/75fd25c889bc949cad71f137f8b0c024107f0670))


### Bug Fixes

* enable multiple replicas for subnet router ([#69](https://github.com/masterpointio/terraform-aws-tailscale/issues/69)) ([190b644](https://github.com/masterpointio/terraform-aws-tailscale/commit/190b644762b5a7ecdc9a894f322a8bcfa4db1ff0))

## [1.8.0](https://github.com/masterpointio/terraform-aws-tailscale/compare/v1.7.0...v1.8.0) (2025-05-22)


### Features

* Expose the "architecture" variable ([#58](https://github.com/masterpointio/terraform-aws-tailscale/issues/58)) ([8662e72](https://github.com/masterpointio/terraform-aws-tailscale/commit/8662e722bccd056a64fa720ba2fecbec7f5bb51d))

## [1.7.0](https://github.com/masterpointio/terraform-aws-tailscale/compare/v1.6.0...v1.7.0) (2025-05-16)


### Features

* allow configuring additional security group rules ([#56](https://github.com/masterpointio/terraform-aws-tailscale/issues/56)) ([e854ea0](https://github.com/masterpointio/terraform-aws-tailscale/commit/e854ea03f2fe100ed9a4e6de7ece462dccc9c485))

## [1.6.0](https://github.com/masterpointio/terraform-aws-tailscale/compare/v1.5.1...v1.6.0) (2025-01-06)


### Features

* enable log rotation + install CW Agent ([#48](https://github.com/masterpointio/terraform-aws-tailscale/issues/48)) ([560774b](https://github.com/masterpointio/terraform-aws-tailscale/commit/560774b0c2a4e5a0a4bcdc06d4c060dd16db4678))

## [1.5.1](https://github.com/masterpointio/terraform-aws-tailscale/compare/v1.5.0...v1.5.1) (2024-11-25)


### Bug Fixes

* avoid RPM lock issue ([#44](https://github.com/masterpointio/terraform-aws-tailscale/issues/44)) ([30b0aca](https://github.com/masterpointio/terraform-aws-tailscale/commit/30b0acaba65aa95bee257cb46b76ddc7d8071a1b))

## [1.5.0](https://github.com/masterpointio/terraform-aws-tailscale/compare/v1.4.0...v1.5.0) (2024-11-21)


### Features

* support AWS SSM tailscaled state ([#41](https://github.com/masterpointio/terraform-aws-tailscale/issues/41)) ([4e9ef78](https://github.com/masterpointio/terraform-aws-tailscale/commit/4e9ef782a5e2f6460c9150e78972bb7e8560dd52))

## [1.4.0](https://github.com/masterpointio/terraform-aws-tailscale/compare/v1.3.0...v1.4.0) (2024-08-20)


### Features

* support extra arguments ([#28](https://github.com/masterpointio/terraform-aws-tailscale/issues/28)) ([6ff5059](https://github.com/masterpointio/terraform-aws-tailscale/commit/6ff5059a5c4a1efa0b3c81b6f92a42ee5f165e3d))

## [1.3.0](https://github.com/masterpointio/terraform-aws-tailscale/compare/1.2.0...v1.3.0) (2024-08-13)


### Features

* adds conventional-title lint check ([73abd18](https://github.com/masterpointio/terraform-aws-tailscale/commit/73abd184189ce062cba882d79ab10b183a1f117c))
* adds release-please for automated releases ([c08d7bb](https://github.com/masterpointio/terraform-aws-tailscale/commit/c08d7bbdffba9038e4e111e984dfbe2e78e1512c))
* allow configuring router as an exit node ([#24](https://github.com/masterpointio/terraform-aws-tailscale/issues/24)) ([3c30878](https://github.com/masterpointio/terraform-aws-tailscale/commit/3c30878166fc694c27cd77ace3879e2a19168556))


### Bug Fixes

* update to use kebab-case name ([f8006ff](https://github.com/masterpointio/terraform-aws-tailscale/commit/f8006ff056060edab3c2b311b014b548156d6204))
