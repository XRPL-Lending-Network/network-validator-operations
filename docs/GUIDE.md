# Running an XRPL mainnet validator: what we learned the hard way

We brought a validator online on mainnet in August 2026. It took two weeks
instead of the two days we planned, and most of that time went into fixing our
own wrong assumptions rather than any actual software.

Theory first, because none of the rest makes sense without it. Then the setup.
Then everything we broke. Honestly, the third part is the useful one.

Every address, key and domain in the examples is made up.

## How the thing actually works

### Nobody mines here

XRPL has no proof-of-work and no proof-of-stake. No miners, no staking, no block
reward. Validators exchange proposals about which transactions belong in the next
ledger, and after two to four rounds they converge on an answer.

A ledger closes about every 3.9 seconds. That is our measurement, not a number
from the docs. Roughly 22,000 ledgers a day.

Now the awkward part. A validator earns nothing at all. Transaction fees are
burned rather than paid to anyone, and there is no issuance headed your way
either. If you came here looking for yield, close this now instead of a month
after buying hardware. We have watched people find out late, and it is an
unpleasant conversation.

### The UNL, or who you trust

Every node keeps a list of validators it trusts, called the UNL, Unique Node
List. Agreement is computed only over that set. The lists themselves ship as
signed blobs, and on mainnet the main publishers are `vl.ripple.com` and
`unl.xrplf.org`.

That split will define your life as an operator. A validator on a UNL has its
vote counted, and its manifest arrives at every node inside the signed list. A
validator outside one runs and signs perfectly well, but nobody counts its vote,
and its identity travels by gossip from node to node.

You do not get onto a UNL quickly. It takes months of stable operation, a
verified domain, a public contact, and somebody willing to vouch for you. You
will start outside, and that is fine.

### The two keys everybody mixes up

A validator has two keys, and confusing them causes half the beginner pain.

The master key is your permanent identity. Generated offline, never placed on
the server, never needed by a running node. If it leaks you cannot reissue it,
only revoke it and lose all the reputation you built.

The ephemeral key, also called the signing key, sits in the config, signs
validations, and is meant to be rotated.

A manifest binds the two. It is a small signed record saying "master key M
authorises key E to sign for me, sequence N, domain D". Manifests travel across
the network, and they are the reason explorers can show your validator under a
readable name instead of a random string.

Remember that word. Manifests come back in part three and ruin several days.

### Node types and amendments

A stock node is the ordinary public kind: visible to the network, accepting
inbound connections, serving ledger data. A validator is the same node plus
`[validator_token]` in the config, and technically nothing else. Full history
nodes and Clio keep the entire chain across tens of terabytes, which a validator
neither needs nor benefits from.

Amendments, briefly: protocol changes get voted on by UNL validators, and a node
that cannot understand an activated amendment stops dead as amendment blocked.
So following releases is mandatory, not optional.

## Setting it up

### Hardware

Numbers from a production node, not from the documentation. Eight cores and up
(ours have 32 and 48, which is generous). Memory from 32 GB, comfortable at 64.
NVMe only, and the capacity gets its own section below. A gigabit link, with
consumption around 0.115 TB per month per peer.

One thing about memory: do not set `[node_size]` by hand. The xrpld sizing matrix
works it out from available RAM and core count, and it does that better than you
will. We once forced `medium` onto a box with 8 GB and collected ten consecutive
OOM kills before admitting whose fault it was.

### Disk, where everyone gets it wrong

The naive "however many ledgers I want to keep" calculation is off by half. Here
is what we measured: 0.70 GB per thousand ledgers in nudb, where the docs suggest
roughly half that. Then `transaction.db`, which grows with the retention window
and usually never makes it into the naive estimate at all.

But that is not the main thing. On rotation NuDB creates a new backend and keeps
the old one as an archive until the next rotation. Two backends on disk at once
is normal operation, not a fault.

So the honest formula looks like this:

```
peak = 2 × (window_ledgers / 1000 × 0.70 GB) + transaction.db + OS
```

For a hundred thousand ledgers that comes to roughly 70 + 70 + 28 + 13, so 181 GB
rather than the 98 our first estimate produced. We caught it six hours before the
first rotation, and only by accident.

There is a related trap next door. `[ledger_history]` and `online_delete` are
different knobs, and the first one is dangerous. `online_delete` retains what the
node already has. `ledger_history` makes it chase down what it lacks from peers,
which means dozens of concurrent downloads competing with live ledger work. Set
`ledger_history none` on a validator and stop thinking about it.

### Hide the validator behind stock nodes

A layout worth copying:

```
               internet
           ┌───────┴────────┐
        stock1            stock2     public, port 51235 open
           └───────┬────────┘
                   │                 private tunnel (WireGuard)
               validator             only SSH exposed
```

The validator has no public peer port at all. It dials out to its own stock nodes
through the tunnel. The stocks are public, hold hundreds of peers, and keep the
validator away from direct contact with the network.

The reasoning is simple. The validator's address is what gets attacked. No
inbound ports, no surface. The firewall here is a second line rather than the
only one, because there is nothing listening to begin with.

```ini
# on the validator
[peer_private]
1
[ips_fixed]
10.0.0.20 51235
10.0.0.21 51235

# on both sides, so they stop charging each other for requests
[cluster_nodes]
n9....
```

`[cluster_nodes]` deserves its own note, because the symptom is completely
misleading. Without it a cold-starting validator burns through the request
allowance at its own stock nodes, they charge it and disconnect it, and you sit
there staring at a perfect config with zero peers.

### The key ceremony

Strictly offline, on a machine with no network:

```bash
validator-keys create_keys
validator-keys create_token --keyfile <path>
validator-keys set_domain validator.example.org --keyfile <path>
```

The first command produces the master key. The keyfile goes into offline storage
on two separate media in two separate places. Only the token travels to the
server, meaning the base64 string from the second command.

`set_domain` issues a new token with an incremented sequence number plus an
attestation string for your website. Keep in mind that every rotation creates a
new sequence number the network still has to learn about.

```ini
[validator_token]
eyJ2YWxpZGF0aW9uX3NlY3J...

[node_seed]
sn....
```

`[node_seed]` pins the machine's identity in the peer network. Without it,
wiping the database changes `pubkey_node` and your cluster neighbours stop
recognising you.

### The domain

One static file at
`https://validator.example.org/.well-known/xrp-ledger.toml`:

```toml
[[VALIDATORS]]
public_key = "nHB..."          # the MASTER key, not the node key
attestation = "..."            # output of set_domain
network = "main"
owner_country = "XX"
server_country = "XX"
```

The requirements are strict: HTTPS only, `Access-Control-Allow-Origin: *`, and
content type `application/toml`. You do not need a working website though,
serving one file is enough. It has nothing to do with the validator host and does
not need to live there.

Once it is up, leave it up. Verification runs both ways, and a missing file reads
to the network as a withdrawn attestation.

### Monitoring

Alerting on "the process is alive" is pointless. Other things are worth watching.

The primary signal is validated ledger age, with a threshold around a minute.
After that: `server_state` outside `full` and `proposing` for more than a couple
of minutes, peer count under a floor (for a validator behind stocks that floor is
exactly two), the `amendment_blocked` flag, disk space accounting for the rotation
peak, and outbound traffic against your provider's quota.

Scrape over a private interface. Do not expose exporters publicly.

### Verify after deployment or restart

Run through this after the first deployment, a planned restart, a configuration
change and a package upgrade. No single step proves the node is healthy; together
they come close.

1. **The node answers.** On the machine itself:

   ```bash
   xrpld server_info
   ```

   If the binary does not find its configuration on its own, point it there:
   `xrpld --conf /etc/xrpld/xrpld.cfg server_info`. An answer proves the process
   is up and nothing more. Do not paste this output anywhere public: it
   describes your node.

2. **The validated ledger is fresh and moving.** `validated_ledger.age` should be
   a few seconds, and `validated_ledger.seq` should be higher when you read it
   again a little later. Look at `server_state` as well, but `server_state` alone
   is not proof that the node is current with the network. The section on
   `server_state: full` below shows how it can say `full` while closing ledgers
   nobody else has.

3. **It agrees with the network.** Take `validated_ledger.seq` from the local
   output, ask an independent node on the same network for that same ledger,
   and compare its hash with the local `validated_ledger.hash`:

   ```bash
   SEQ='<VALIDATED_LEDGER_SEQ>'
   curl -s -H 'Content-Type: application/json' \
     -d "{\"method\":\"ledger\",\"params\":[{\"ledger_index\":$SEQ}]}" \
     '<INDEPENDENT_NODE_URL>' | jq -r '.result.ledger_hash'
   ```

   The same hash at the same index means you are on the network's chain. Compare
   at a fixed index rather than comparing two "latest" values: two reads taken a
   few seconds apart will be a ledger or two apart, and that difference means
   nothing.

4. **The peers are the expected ones.** The `peers` number counts connections,
   not the right connections. Check with `xrpld peers` that the node holds the
   expected stock-node connections: a validator should be connected to its own
   stock nodes, and each stock node should see the validator behind it as well
   as the wider network.

5. **Validator identity, for nodes that validate.** For nodes intended to
   validate and configured with a validator token, verify the expected public
   validator identity using local admin `server_info`: `pubkey_validator` should
   be the master public key you published, the one starting `nHB...`. A node in
   validator topology that runs without a token on purpose is an ordinary peer:
   its `pubkey_validator` reads `none`, and that is correct.

6. **Proposing, for the same nodes.** After synchronization, these nodes should
   normally reach `proposing`. A validation-enabled node that does not reach or
   keep a synchronized `proposing` state needs investigating. This step and the
   previous one do not apply to a node without a token.

7. **Not amendment blocked.** `server_info` includes `amendment_blocked` only
   when the node is blocked. If it is there, the node is not healthy, whatever
   `server_state` and the peer count say.

8. **Upgrades: stock nodes first, validator last.** Upgrade the stock nodes one at
   a time and run this check against the network after each one. Upgrade the
   validator last, then go through the whole list again.

## What we broke

### `server_state: full` does not mean you are on the network

The sneakiest one of the lot. Our nodes reported `full`, peers were present, the
logs were perfectly quiet. And the validated ledger was seventeen minutes old. We
had drifted into a pocket of stale nodes that had fallen behind together and were
agreeing with each other beautifully.

`server_state` only tells you the node agrees with somebody. Not that the somebody
is the network.

Check against an external node instead:

```bash
curl -s -H 'Content-Type: application/json' -d '{"method":"server_info"}' \
  https://xrplcluster.com/ | jq '.result.info.validated_ledger.seq'
```

A gap over a couple of hundred means you are behind.

### Wrong log level and you are blind

Accepting a new manifest gets logged at info level in the `ManifestCache`
partition. With a global level of `warning` your log shows nothing whatsoever,
and you conclude "manifests are not arriving" when the truth is "we are not
logging them".

We walked into this twice, a week apart. The second time stung.

```ini
[rpc_startup]
{ "command": "log_level", "severity": "warning" }
{ "command": "log_level", "partition": "ManifestCache", "severity": "info" }
```

The commands run in order: silence everything, then bring back what you need.

### We raised the peer cap and made things worse

The `[peers_max]` default is 21. We pushed it to 60 on the theory that more nodes
knowing us is better. The node hit the new ceiling and started refusing inbound
connections.

Inbound connections are exactly the nodes that just restarted. They are the only
ones with room in their manifest cache, and the only ones capable of learning a
new key. We had shut the door on the very people we were trying to reach.

The goal is not "more connections" but "always keep a free slot for a newcomer".
Keep the cap well above your actual peer count. Outbound connections are capped
internally at sixteen and are not affected by this setting.

### `max_untrusted_count` gates inbound too

`[overlay] max_untrusted_count` arrived in 3.3.0 and reads like "how many foreign
manifests I keep". It actually does three things: cache size, the number of
manifests in an outgoing message, and the maximum size of a message the node will
accept.

We set it to 50 and made our nodes silently discard manifest packets from
everyone running the default of 300. No error, no disconnect, not one log line.
We found out a week later, by accident.

Leave it alone until you understand all three effects.

### Manifests do not survive restarts

This one is non-obvious and matters. Manifests belonging to validators outside
the UNL are not written to disk by anyone. The source comment says it plainly:
`so untrusted gossip never survives a restart`.

On top of that the untrusted key cache is bounded and never evicts anything, and
the header states as much: `Entries are never evicted`. A freshly started node
fills its entire allowance in 1.8 seconds and stays deaf until its next restart.

The practical consequence is that recognisability for an off-UNL validator
accumulates slowly and resets on every restart, yours and everyone else's. Over
three days we collected four nodes that knew our manifest, then lost all four to
a single restart of our own. Do not restart nodes without a reason.

### The August 2026 story, worth knowing

On 31 July the network was hit by a manifest flood, and on 1 August an emergency
hotfix 3.2.1 shipped with hard limits on propagating manifests from untrusted
validators. The side effect landed on everyone outside the UNL: explorers stopped
showing them under their master key and started showing the ephemeral one instead.

Release 3.3.0 lifted part of the restriction without closing the issue. The cache
still evicts nothing, and the share of off-UNL validators with a resolved identity
did not move a single point over a week, while the share of nodes running 3.3.0
doubled in the same period.

One more thing to check before blaming the network. Part of the symptom lives
outside rippled, in explorer infrastructure. If your validator shows under its
ephemeral key while the domain displays correctly, then the explorer already has
your manifest in its database and the fault is in how it serves the record, not in
propagation. One query against its manifest archive settles it.

The topic is alive in the rippled tracker (the discussion about manifest gossip
for non-UNL validators) and in the XRPScan tracker, where a maintainer replies and
knows what is going on.

### Small things that each ate an evening

Use a `/32` mask for WireGuard, not `/24`. A subnet-wide mask creates a route
through the tunnel and drags unrelated traffic into it, for instance to your
provider's DNS servers living in the same range. It fails neither immediately nor
obviously.

With two addresses on one interface, set `src` explicitly. Otherwise the kernel
picks the wrong source and the far end quietly drops your packets. Lovely
symptom: the handshake succeeds, counters climb, peer count zero.

Put the database on its own partition. Filling the root filesystem takes the whole
machine with it: no logs, no apt, and sshd may refuse to let you in.

Upgrade stock nodes first and the validator last. Then verify against the network
rather than against your own `server_state`, see the first item.

## Before you launch

- [ ] Master key generated offline, keyfile on two media in two locations
- [ ] Only the token on the server
- [ ] `[node_seed]` set
- [ ] `[peer_private] 1`, no public peer port on the validator
- [ ] `[cluster_nodes]` configured on both sides
- [ ] `[node_size]` not hardcoded
- [ ] `ledger_history none`, `online_delete` sized for two backends
- [ ] Database on its own partition with room for the rotation peak
- [ ] `ManifestCache` at info
- [ ] `[peers_max]` comfortably above your actual peer count
- [ ] Alert on validated ledger age
- [ ] Version pinned explicitly
- [ ] `xrp-ledger.toml` published

## How long it takes

The first few minutes the node gathers peers and synchronises. Within an hour it
reaches `proposing`. Within a day agreement settles at a hundred percent. After
that come weeks and months of building recognisability, a domain and a reputation,
and only then is there any point discussing a UNL.

Over ten days ours signed 262,000 ledgers with 99.66% agreement and missed 891,
nearly all of them in the first days while we were migrating between versions.
None since.

If you still want your own validator after reading this, one last piece of advice:
check the node against the network rather than against its own opinion of itself.
It is not lying to you on purpose. It genuinely believes it is fine.
