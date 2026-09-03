<!--
Describe the change and why it is needed. If it corrects something in the
guide, say what the old text got wrong — that is worth recording.
-->

## What this changes

## Why

<!--
For a role change: what breaks without it, and how does the failure look?
Several things in this repository look healthy while being broken, so
"what the symptom was" is the useful part.

For a guide change: what was wrong, and what did you observe instead?
-->

## Impact on existing deployments

<!-- Check what applies, delete the rest. -->

- [ ] Adds a variable with a default (safe: existing `group_vars` keep working)
- [ ] **Changes a default** (existing deployments change behaviour on next run)
- [ ] **Renames or removes a variable** (breaking: runs fail, or silently skip)
- [ ] Changes the generated `xrpld.cfg` or `validators.txt`
- [ ] Triggers a service restart where it previously did not

## How it was tested

<!--
Which network — testnet, devnet, mainnet? Which xrpld version? Stock node,
validator, or both? `--check --diff` only is a fine answer, just say so.
-->

## Checklist

- [ ] `pre-commit run --all-files` passes
- [ ] `ansible-playbook -i inventory.example.yml playbooks/site.yml --syntax-check` passes
- [ ] No real addresses, keys or domains: examples use RFC 1918 / RFC 5737 and `example.org`
- [ ] Commits are signed
