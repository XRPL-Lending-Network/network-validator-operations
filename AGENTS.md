# AGENTS.md

Instructions for coding agents working in this repository. People should start
with [README.md](README.md) and [CONTRIBUTING.md](CONTRIBUTING.md); this file
condenses the parts an agent needs and adds nothing that contradicts them.

## What this is

An Ansible role, `xrpld`, that deploys one shape of XRP Ledger deployment: a
validator that talks only to stock nodes of the same operator, and stock nodes
that face the network. [docs/GUIDE.md](docs/GUIDE.md) explains that shape and
records what went wrong while building it. Both halves are in scope.

## Layout

- `ansible/playbooks/site.yml`: stock nodes first, one at a time
  (`serial: 1`), then the validator.
- `ansible/roles/xrpld/defaults/main.yml`: every variable, with a comment on
  what breaks if it is wrong. Per-network values live in `xrpld_networks`.
- `ansible/roles/xrpld/tasks/`: `repo`, `install`, `config`, `service`, `wait`.
- `ansible/roles/xrpld/templates/`: `xrpld.cfg.j2`, `validators.txt.j2`.
- `ansible/*.example.yml`, `ansible/group_vars/*.example.yml`: templates for
  operators. The non-example copies are gitignored and must stay that way.
- `tests/render.yml`: renders both templates for both node roles on mainnet,
  testnet and devnet and checks their content.
- `tests/run.sh`: runs the config tasks in check mode against two local hosts
  (`tests/inventory.yml`) and checks what the role accepts, what it refuses
  and that no secret reaches the output.

## Checks

Python 3.12 and ansible-core 2.21.5 (CI also runs 2.16.14, the oldest
supported release). No target host, root or network access is needed.

```bash
pip install ansible-core==2.21.5 ansible-lint==26.10.1 pre-commit
pre-commit run --all-files
(cd ansible && ansible-playbook -i inventory.example.yml playbooks/site.yml --syntax-check)
(cd ansible && ansible-lint)
ansible-playbook -i localhost, tests/render.yml
bash tests/run.sh
```

`pre-commit` runs yamllint 1.37.1, the version CI uses, with `.yamllint.yml`.
All of the above must pass before a change is done. `tests/run.sh` ends with
`all checks passed`; any `FAIL` line is a failure.

## Rules for changes

- **No real infrastructure.** Addresses come from `10.0.0.0/8` or
  `203.0.113.0/24`, domains are `example.org`, validator keys are truncated
  (`nHB...`). Never add a real key, token, seed, address or hostname, not even
  in a test or a comment.
- **Secrets stay out of output.** `xrpld.cfg` carries the decrypted validator
  token and node seed, so its template task has `diff: false`. Do not remove
  it, and do not add a task, debug message or failure text that prints
  `xrpld_validator_token` or `xrpld_node_seed`. `tests/run.sh` checks this with
  sentinel values.
- **Network differences go in `xrpld_networks`**, never inline in a task or
  template. A wrong peer port produces a node that looks healthy and is not
  on the network.
- **New variables** need a default in `defaults/main.yml` and a comment saying
  what goes wrong if the value is wrong.
- **Silent failures get an assertion.** The model is the check that a
  validator has a non-empty `xrpld_stock_peers`. A new assertion needs a
  `refuses` case in `tests/run.sh`; a change to rendered config needs a check
  in `tests/render.yml`.
- **Keep rollouts safe.** Do not remove `serial: 1` for stock nodes or the
  wait for sync in `tasks/wait.yml`.
- Use fully qualified module names (`ansible.builtin.template`). ansible-lint
  runs the `production` profile.
- YAML follows `.yamllint.yml`: lines up to 120 characters, no implicit or
  explicit octal (`mode: "0640"` as a string).
- **Out of scope:** operating system hardening, firewalls, the private network
  between hosts, monitoring, and automating the validator key ceremony. Do not
  add them.

## Do not

- Run the playbook against real hosts, or create `ansible/inventory.yml` or
  non-example `group_vars` files with real values.
- Decrypt Vault values, generate validator keys, or handle a master key.
- Rewrite the published history of `main`.

## Documentation

- A statement of fact in `docs/GUIDE.md` or the README needs a source: the
  xrpld code or documentation, or something observed on a node. If a change
  makes existing text wrong, fix the text in the same change.
- User-visible changes get a line under `[Unreleased]` in `CHANGELOG.md`. A
  renamed or removed variable, or a changed default, also needs an upgrade
  note.
- Write in English, in the plain style of the existing documents.

## Commits

- Subject: `feat:`, `fix:`, `docs:`, `ci:`, `refactor:` or `chore:`, then a
  capitalised first word and no final period, for example
  `fix: Read the peer port from the network map`.
- Commits are signed.
- Once a pull request is under review, push fixes as new commits instead of
  force-pushing.
