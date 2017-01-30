#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
WD=$(realpath .)

CLEAN_EXIT=0

export IPTB_ROOT="$WD/iptb_bed/)"

SPEC=${1?"Usage: $0 spec.json"}
CLEAN_SEPC=$(mktemp)
jq -cS . "$SPEC" > "$CLEAN_SEPC"
SPEC_HASH=$(sha256sum "$CLEAN_SEPC" | head -c 16)
echo "Spec ID:"
echo "SPEC_HASH"
echo

geto() {
	jq -r ".$1" "$SPEC"
}

cleanup() {
	rm -rf "$CLEAN_SEPC"

	if [[ "$CLEAN_EXIT" -ne 1 ]]; then
		echo "Stopping IPTB"
		iptb stop || true
	fi
}

source "$WD/tests/$(geto test)"

trap cleanup EXIT

iptb init -n "$IPTEST_NODES"
iptb for-each ipfs config --json Datastore.NoSync "$(geto nosync)"

DSET="$(mktemp -d -p "$WD" dataset.XXXXXXX)"
ODIR="$(mktemp -d -p "$WD" output.XXXXXXX)"

random-files -files "$(geto dataset.files)" -filesize "$(geto dataset.filesize)" \
	-depth "$(geto dataset.depth)" -dirs "$(geto dataset.dirnum)" "$DSET" > /dev/null 2>&1

iptb for-each ipfs bootstrap rm all > /dev/null 2>&1
iptb start
iptb connect 0 "[1-$((IPTEST_NODES-1))]"


TMPFILE=$(mktemp)
for i in 0 $((IPTEST_NODES - 1)); do
	awk -F '/' '{print "\"" $3 ":" $5 "\""}' "$(iptb get path $i)"/api
done | jq -s '[ .[] | {targets: [.]} ]' > "$TMPFILE"

jq "[ .[] | .labels = { \"hash\": \"$SPEC_HASH\" } ]" "$TMPFILE" | sponge "$TMPFILE"

for i in 0 $((IPTEST_NODES - 1)); do
	jq '.['$i'].labels.role = "'"$(iptest_nodes_roles $i)\"" "$TMPFILE" | sponge "$TMPFILE"
done

mv -f "$TMPFILE" ./prom_end.json

iptest_run "$DSET" "$ODIR"

# if run was successful, save the spec to a file with its hash
jq "{\"$SPEC_HASH\" : . }" "$CLEAN_SEPC" | jq -s '.[0] * .[1]' past_specs.json - | sponge past_specs.json

iptb stop
CLEAN_EXIT=1


