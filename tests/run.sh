#!/usr/bin/env bash
# Runs the role against two local hosts in check mode and checks what it
# accepts, what it refuses and what it prints. No target machine, no root, no
# real keys: every secret below is a made-up sentinel.
#
#   bash tests/run.sh
set -u
cd "$(dirname "$0")/.."
# A host pattern that matches nothing makes ansible-playbook exit 0, which
# would let every check below pass without running anything.
export ANSIBLE_HOST_PATTERN_MISMATCH=error
export ANSIBLE_INVENTORY_UNPARSED_FAILED=true
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

play() {
  local host=$1; shift
  (cd ansible && ansible-playbook -i ../tests/inventory.yml playbooks/site.yml \
    --limit "$host" --tags "${TAGS:-config}" --check --diff \
    -e ansible_become=false \
    -e "xrpld_config_dir=$work/etc xrpld_database_path=$work/db xrpld_log_file=$work/log/debug.log" \
    -e "xrpld_user=$(id -un) xrpld_group=$(id -gn)" \
    "$@") > "$work/out" 2>&1
}

pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; sed 's/^/      /' "$work/out" | tail -20; failures=$((failures + 1)); }

ran() { grep -Eq "^$1 +: ok=" "$work/out"; }

accepts() {
  local name=$1 host=$2
  if play "${@:2}" && ran "$host"; then pass "$name"; else fail "$name"; fi
}

refuses() {
  local name=$1 message=$2; shift 2
  if play "$@"; then fail "$name (was accepted)"
  elif grep -q -- "$message" "$work/out"; then pass "$name"
  else fail "$name (failed for another reason)"; fi
}

hides() {
  local name=$1 sentinel=$2 host=$3
  if ! play "${@:3}" || ! ran "$host"; then fail "$name (run failed)"
  elif grep -q -- "$sentinel" "$work/out"; then fail "$name (secret printed)"
  else pass "$name"; fi
}

accepts "stock node" test-stock
accepts "validator with stock peers" test-validator
accepts "stock node with public WebSocket" test-stock -e xrpld_ws_public_port=6007
refuses "unknown node role" "is not supported" test-stock -e xrpld_node_role=validtor
refuses "unknown network" "is not described" test-stock -e xrpl_network=moonnet
refuses "validator without stock peers" "that list is empty" test-validator -e '{"xrpld_stock_peers": []}'
refuses "validator with public WebSocket" "Public WebSocket access must be disabled" \
  test-validator -e xrpld_ws_public_port=6007
refuses "validator reached over a public address" "not a private address" \
  test-validator -e ansible_host=203.0.113.50
accepts "validator with its private address set" test-validator \
  -e ansible_host=203.0.113.50 -e xrpld_private_address=10.0.0.10
# The refused addresses below are routable on purpose: they sit just outside
# each private range, which is what a boundary test needs.
for address in 10.1.2.3 172.16.0.1 172.31.255.1 192.168.1.1 100.64.0.1 100.127.0.1 fd12:3456::1 FD12::1; do
  accepts "private address $address" test-validator -e "xrpld_private_address=$address"
done
for address in 11.0.0.1 172.15.0.1 172.32.0.1 192.169.0.1 100.63.0.1 100.128.0.1 2001:db8::1; do
  refuses "public address $address" "not a private address" test-validator -e "xrpld_private_address=$address"
done
accepts "private range added by the operator" test-validator -e xrpld_private_address=198.18.0.5 \
  -e '{"xrpld_validator_private_ranges": ["^198[.]18[.]"]}'
TAGS=repo refuses "old apt channel variable" "are no longer used" test-stock -e xrpld_apt_component=stable
TAGS=repo refuses "old apt channel key in the network map" "are no longer used" test-stock \
  -e '{"xrpld_networks": {"testnet": {"network_id": "testnet", "apt_component": "stable"}}}'

hides "token and seed stay out of --diff" SENTINEL test-validator \
  -e xrpld_validator_token=SENTINELTOKEN -e xrpld_node_seed=SENTINELSEED

printf 'test-vault-password\n' > "$work/vault-pass"
{
  printf 'VAULTSENTINELTOKEN' | ansible-vault encrypt_string \
    --vault-password-file "$work/vault-pass" --stdin-name xrpld_validator_token
  printf 'VAULTSENTINELSEED' | ansible-vault encrypt_string \
    --vault-password-file "$work/vault-pass" --stdin-name xrpld_node_seed
} > "$work/secrets.yml" 2>/dev/null
hides "vault-encrypted token and seed stay out of --diff" VAULTSENTINEL test-validator \
  -e "@$work/secrets.yml" --vault-password-file "$work/vault-pass"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
