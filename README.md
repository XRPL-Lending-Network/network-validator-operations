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
git clone <this repo> && cd network-validator-operations/ansible
cp inventory.example.yml inventory.yml
for f in all stock validators; do cp group_vars/$f.example.yml group_vars/$f.yml; done
# edit inventory.yml and group_vars/*.yml
ansible-playbook playbooks/site.yml --check --diff
ansible-playbook playbooks/site.yml
```

`inventory.yml` and the non-example `group_vars` are gitignored, so real
addresses and keys do not end up committed by accident.

Start on testnet. `xrpl_network` in `group_vars/all.yml` is the only place the
network is named; everything that differs between networks lives in the role's
network map.

## What the role does and does not do

It installs the package from Ripple's apt repository, writes `xrpld.cfg` and
`validators.txt`, and manages the service. That is all, on purpose. It does
not harden the operating system, set up a firewall, build a private network
between your machines, or install monitoring; those are yours to make
decisions about, and a role that quietly made them for you would be worse.

For monitoring, [xrpl-vantage](https://github.com/XRPL-Lending-Network/xrpl-vantage) is
the companion piece: an exporter and alert rules for exactly this shape of
deployment, including the failures described in the guide.

## The key ceremony is not automated, deliberately

The master key is generated offline with `validator-keys`, on a machine that
never touches the network, and it stays there. Only the token it produces
travels, and it travels encrypted:

```bash
ansible-vault encrypt_string --name xrpld_validator_token '<token>'
```

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

Ubuntu 24.04 and ansible-core 2.14 or newer. Tested against xrpld 3.3.0.

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
