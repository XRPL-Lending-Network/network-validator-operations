# XRPL Lending Network Validator Operations

Ansible for running an XRP Ledger validator, and a write-up of what went wrong
while we worked it out.

We brought a validator up on mainnet in August 2026. It took two weeks instead
of the two days we planned, and most of that time went on fixing our own wrong
assumptions rather than on software. **[docs/GUIDE.md](docs/GUIDE.md)** is
that account: how the thing actually works, how to set it up, and a long
section on what we broke. The third part is the useful one.

The Ansible here builds the shape the guide describes: a validator that talks
only to stock nodes of your own, and stock nodes that face the network.

```
                       the network
                            |
                 +----------+----------+
                 |                     |
              stock1                stock2      public peers
                 |                     |
                 +----------+----------+
                            |
                        validator                no public address,
                                                 not in peer discovery
```

## Quick start

```bash
git clone https://github.com/XRPL-Lending-Network/network-validator-operations.git
cd network-validator-operations/ansible
cp inventory.example.yml inventory.yml
for f in all stock validators; do cp group_vars/$f.example.yml group_vars/$f.yml; done
# edit inventory.yml and group_vars/*.yml
ansible-playbook playbooks/site.yml --check --diff
ansible-playbook playbooks/site.yml
```

On a first deployment every node syncs from an empty database before the run
moves on to the next one. On mainnet that can take longer than the default
wait of ten minutes, so raise it for that run:
`ansible-playbook playbooks/site.yml -e xrpld_ready_retries=180`.

`--diff` shows the changes to every file except `xrpld.cfg`. That one carries
the decrypted validator token and node seed, so the role never prints its diff.

`inventory.yml` and the non-example `group_vars` are gitignored, so real
addresses and keys do not end up committed by accident.

Start on testnet. `xrpl_network` in `group_vars/all.yml` is the only place the
network is named; everything that differs between networks lives in the role's
network map.

## What the role does and does not do

It installs the package from the XRP Ledger Foundation's apt repository, writes
`xrpld.cfg` and
`validators.txt`, and manages the service. Stock nodes are restarted one at a
time, each only after the previous one reports itself synced again. That is
all, on purpose. It does not harden the operating system, set up a firewall,
build a private network between your machines, or install monitoring; those
are yours to make decisions about, and a role that quietly made them for you
would be worse. For monitoring, see [below](#monitoring).

## The key ceremony is not automated, deliberately

The master key is generated offline with `validator-keys`, on a machine that
never touches the network, and it stays there. Only the token it produces
travels, and it travels encrypted:

```bash
ansible-vault encrypt_string --stdin-name xrpld_validator_token
```

Paste the token, press Enter, then Ctrl-D. Passed as an argument instead, the
token would stay in your shell history. The newline Enter adds is trimmed when
the config is written.

Automating the ceremony would mean the master key passing through a playbook,
a log, or a temporary file. Whoever holds that key can take over your
validator's identity or destroy it, so it is worth the manual step. The guide
covers the ceremony in full.

## Four things that cost us the most time

Each of these is expanded in the guide with what the symptom looked like.

**`server_state: full` does not mean you are on the network.** A node with the
wrong peer port opens a TCP connection, receives validator proposals, looks
healthy, and quietly closes empty ledgers of its own because it can never
download ledger data. Check against the network, not against the node's
opinion of itself.

**The peer port differs per network.** Mainnet is 51235, test and dev networks
answer on 2459. Documentation has had this wrong. Read it from the hub's own
`server_info`.

**Budget twice your history window on disk, plus more.** Rotation creates a
second backend alongside the first and only deletes the old one at the next
rotation, so two live backends is the steady state. The SQLite transaction
database is on top of that, is not in any per-ledger estimate, and never
shrinks.

**A blanket `warning` log level makes you blind to manifests.** The one line
telling you the node accepted a neighbour's manifest is logged at `info`,
once per key for the life of the process. The role raises that one partition
back up; do not remove it before reading why.

## Requirements

Ubuntu 24.04 and ansible-core 2.16 or newer. 2.16 is the first release that
supports Python 3.12, which Ubuntu 24.04 ships, on the managed host; it needs
Python 3.10 to 3.12 on the machine you run it from.

| | Version | How it was checked |
|---|---|---|
| ansible-core | 2.16.14 and 2.21.5 | Syntax, lint, template renders and config checks in CI |
| xrpld | 3.4.1 | Rendered config compared with our mainnet nodes, 2026-10-24 |
| Managed hosts | Ubuntu 24.04 | Target platform; a fresh install has not been run for this release |

The layout the role renders is the one our own mainnet validator and stock
nodes run on xrpld 3.4.1, compared on 2026-10-24: admin ports on loopback, the
validator's peer port on its private address with `[peer_private]` and fixed
connections to two stock nodes, the stock nodes public and fixed to the network
hub, cluster keys on all three. Node size, retention and the peer cap are set
per host there, as they should be here.

Changes between releases are in [CHANGELOG.md](CHANGELOG.md).

## Monitoring

[xrpl-vantage][vantage] is the companion piece: a Prometheus exporter, a Grafana
dashboard and alert rules built for exactly this shape of deployment, including
the failure modes described in the guide.

## Maintained by

Maintained by [XRPL Lending Network][org].

This is an independent project. It is not affiliated with, endorsed by, or
maintained by the XRP Ledger Foundation or Ripple. `xrpld` and the XLS
specifications are the normative sources; everything here is downstream of them.

[vantage]: https://github.com/XRPL-Lending-Network/xrpl-vantage
[org]: https://github.com/XRPL-Lending-Network

## Licence

MIT.
