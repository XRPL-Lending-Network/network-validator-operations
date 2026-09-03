# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Use GitHub's [private vulnerability reporting][pvr] on this repository. We aim
to acknowledge a report within 72 hours.

**Never include real infrastructure in a report.** No inventories, no host
addresses, no configuration files taken off a live machine, and above all no
keys. A redacted reproduction is more useful than a real one, and a validator
master key pasted into a report cannot be un-pasted.

## Not in scope

Vulnerabilities in the XRP Ledger itself — `xrpld`, `clio`, the client
libraries — belong to the XRP Ledger Foundation's process, not here. See
[rippled's security policy][xrplf].

## What this kit assumes, and does not do

Worth stating plainly, because it defines what counts as a vulnerability here.

**The master key never touches a managed machine.** It is generated offline
with `validator-keys` and stays there. Only the token it produces is deployed,
and the role expects it to arrive encrypted with `ansible-vault`. Any change
that would make a master key pass through a playbook, a log line, a fact, or a
temporary file is a vulnerability in this role, and we want to hear about it.

**Secrets in transit through Ansible.** `xrpld_validator_token` and
`xrpld_node_seed` are secrets. They are written into `xrpld.cfg` with mode
`0640`, owned by root and readable by the service group. Anything that widens
those permissions, copies the values elsewhere on disk, or exposes them in
task output — a `debug` on the wrong variable, a `register` that gets printed,
a template rendered somewhere world-readable — is in scope.

**The role does not secure the host.** It does not configure a firewall, does
not harden SSH, and does not build the private network the validator depends
on. A deployment that exposes the validator to the open network is a
deployment mistake, not a bug in the role. The guide explains the intended
shape and why.

**Admin RPC is privileged.** The generated configuration binds it to loopback.
A change that moves it, or that widens the admin allow-list, is in scope.

**Upstream package trust.** The role installs from Ripple's apt repository,
verified by that repository's signing key. Anything that weakens that
verification — an unsigned source, a downgraded transport, a key fetched over
plain HTTP — is in scope.

## Testing

Never test against XRPL Mainnet. `xrpl_network: testnet` is the default in the
example variables for that reason.

[pvr]: https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability
[xrplf]: https://github.com/XRPLF/rippled/blob/develop/SECURITY.md
