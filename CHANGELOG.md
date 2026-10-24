# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-24

First tagged release. It follows an external review of the role and the guide,
and a comparison of the rendered configuration with our own mainnet nodes.

### Upgrading from an untagged checkout of main

- Packages now come from packages.xrplf.org, which carries 3.4.0 and later
  only. Drop or raise an `xrpld_version` pin to 3.3.x before the first run.
- Rename `xrpld_apt_component` to `xrpld_apt_channel`, and `apt_component` to
  `apt_channel` in your own `xrpld_networks`. The role stops if either old
  name is still set.
- Set `xrpld_private_address` on validators reached over a public address.
  The role now refuses a validator whose peer port would listen on an address
  that is not private; add ranges to `xrpld_validator_private_ranges` if your
  private network uses others.
- ansible-core 2.14 and 2.15 are no longer supported.
- Runs now wait for each node to sync and stop if one does not. On a first
  deployment, raise `xrpld_ready_retries`.

### Security

- The task that writes `xrpld.cfg` no longer shows a diff, so `--check --diff`
  does not print the decrypted validator token and node seed.
- A validator's peer port listens on `xrpld_private_address` when it is set,
  and the role refuses a validator whose peer port would listen on an address
  that is not private. Before, it always used `ansible_host`, which put the
  peer port on the public address of a validator reached over SSH that way.
- The working `ansible/group_vars/*.yml` files are now ignored by git, as the
  README already said they were. CI fails if that stops being true.
- The README and the validators example encrypt the token from standard input
  instead of passing it as an argument, which would leave it in shell history.

### Added

- Stock nodes are restarted one at a time. After a restart, and at the end of
  every run whatever the tags, the role waits until the node reports a synced
  state, a recent validated ledger and at least one peer, and stops the run if
  it does not. New variables: `xrpld_wait_for_sync`, `xrpld_ready_states`,
  `xrpld_ready_max_ledger_age`, `xrpld_ready_retries`, `xrpld_ready_delay`.
- `xrpld_private_address` sets where a validator's peer port listens, and
  `xrpld_validator_private_ranges` lists the address ranges accepted for it.
- The role installs `python3-debian` on the managed host before adding the apt
  repository, because `deb822_repository` needs it.
- Offline tests: `tests/render.yml` renders the templates for both node roles
  on mainnet, testnet and devnet and checks their contents; `tests/run.sh` runs
  the config tasks in check mode against local hosts and checks what they
  accept, what they refuse and that no secret reaches the output. CI runs both
  on the minimum and the current ansible-core.

### Changed

- **Packages come from the XRP Ledger Foundation**,
  `https://packages.xrplf.org/repository/deb-<channel>`. The old repository on
  `repos.ripple.com` stops at 3.3.0 for Ubuntu 24.04. The role removes the old
  apt source from hosts set up by earlier versions.
- **`xrpld_apt_component` is replaced by `xrpld_apt_channel`** (`stable`, `rc`,
  `beta` or `develop`), and the `apt_component` key of the network map by
  `apt_channel`. The role fails with a message if an old name is still set,
  rather than ignoring it.
- The minimum supported version is ansible-core 2.16. 2.14 lacks
  `deb822_repository`, and 2.15 does not support Python 3.12 on the managed
  host, which is what Ubuntu 24.04 ships. CI pins the versions of ansible-core
  and ansible-lint it uses.
- The template trims the validator token and node seed, so a trailing newline
  from a pasted value does not add a blank line. Configs rendered from values
  without surrounding whitespace are unchanged.

### Fixed

- The key ceremony in the guide now deploys the token printed by `set_domain`,
  not the earlier one from `create_token`, and says to back up the keyfile
  again after every change of sequence.
- The guide, the defaults and the stock example no longer claim a fixed cap of
  sixteen outbound connections. They describe how xrpld 3.3.0 splits
  `[peers_max]` between outbound and inbound.
- The guide no longer claims a validator has no listening surface, compares
  the master key in full instead of by its prefix, and describes
  `application/toml` as the recommended content type for `xrp-ledger.toml`.

[Unreleased]: https://github.com/XRPL-Lending-Network/network-validator-operations/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/XRPL-Lending-Network/network-validator-operations/releases/tag/v1.0.0
