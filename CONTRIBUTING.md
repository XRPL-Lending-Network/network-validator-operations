# Contributing

Corrections are especially welcome. Much of what is written here came from
getting it wrong first, and there is no reason to think that stopped.

## What this repository is

Two things that belong together: an Ansible role that builds one specific
shape of deployment — a validator that talks only to stock nodes of your own —
and `docs/GUIDE.md`, which explains why that shape and what went wrong on the
way to it.

Both halves are in scope. A patch to the guide that corrects a fact, adds a
failure mode, or replaces a guess with a measurement is as useful as a patch
to the role.

## What the role deliberately does not do

It installs the package, writes `xrpld.cfg` and `validators.txt`, and manages
the service. It does not harden the operating system, configure a firewall,
build the private network between your machines, or install monitoring.

Those are decisions an operator has to make with their own threat model and
their own provider in front of them, and a role that quietly made them would
be worse than one that does not. Please do not send patches that add them —
open an issue first if you think one of these lines has moved.

## Never commit real infrastructure

`inventory.yml` and the non-example `group_vars/*.yml` are gitignored for a
reason. Every address in this repository is either RFC 1918 or from the
documentation range reserved by RFC 5737; every key and domain is invented.

Keep it that way in patches:

- addresses go in `10.0.0.0/8` or `203.0.113.0/24`
- domains are `example.org` or `validator.example.org`
- validator keys are truncated (`nHB...`), never real ones

A master key must never appear in this repository, in an issue, or in a bug
report — not even one you have already rotated away from.

## Changing the role

- Keep FQCN module names (`ansible.builtin.apt`, not `apt`). The linter
  enforces it and it survives collection reshuffles.
- Anything that differs between mainnet, testnet and devnet belongs in
  `xrpld_networks` in `defaults/main.yml`, never inline in a task. The peer
  port is the reason: getting it wrong produces a node that looks healthy and
  is not on the network at all.
- New variables need a default and a comment saying what breaks if it is
  wrong. Several defaults here carry a paragraph; that is intentional.
- Assertions that catch a silent failure are welcome. `xrpld_stock_peers`
  being empty is the model: it fails the run instead of producing a validator
  that starts, reports itself healthy, and never sees a ledger.

## Before making a pull request

Install the hooks once:

```bash
pip install pre-commit
pre-commit install
```

They run on every commit, and on demand:

```bash
pre-commit run --all-files
```

The playbook should also parse:

```bash
cd ansible && ansible-playbook -i inventory.example.yml playbooks/site.yml --syntax-check
```

Hook versions are pinned by commit hash, so a local run uses the same tool
versions as CI.

Testing a change against real machines is better than not, but not everyone
has three spare hosts. If you could not run it, say so in the pull request —
a reviewed patch that has not been executed is still worth having, it just
needs someone else to run it.

## Pull requests

Start the title with one of these:

- `feat:` — new capability in the role
- `fix:` — corrects behaviour
- `docs:` — the guide or the README
- `ci:` — CI configuration
- `refactor:` — no behaviour change
- `chore:` — anything else

Capitalise the first word after the colon and leave the subject without a
final period: `fix: Read the peer port from the network map`.

Once a pull request is ready for review, add changes as new commits rather
than force-pushing, so a reviewer can see what moved since their last look.

Commits should be signed. GitHub's guide to [commit signature verification][s]
covers the setup.

[s]: https://docs.github.com/en/authentication/managing-commit-signature-verification
