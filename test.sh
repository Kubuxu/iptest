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

geto() {
	jq -r ".$1" "$SPEC"
}

cleanup() {
	rm -rf $CLEAN_SEPC

	if [[ "$CLEAN_EXIT" -ne 1 ]]; then
		echo "Stopping IPTB"
		iptb stop || true
	fi
}
trap cleanup EXIT

iptb init -n 2
iptb for-each ipfs config --json Datastore.NoSync "$(geto nosync)"

DSET="$(mktemp -d -p "$WD" dataset.XXXXXXX)"

random-files -files "$(geto dataset.files)" -filesize "$(geto dataset.filesize)" \
	-depth "$(geto dataset.depth)" -dirs "$(geto dataset.dirnum)" "$DSET" > /dev/null 2>&1

iptb for-each ipfs bootstrap rm all > /dev/null 2>&1
iptb start
iptb connect 0 1


TMPFILE=$(mktemp)
for i in 0 1; do
	awk -F '/' '{print "\"" $3 ":" $5 "\""}' "$(iptb get path $i)"/api
done | jq -s '[ .[] | {targets: [.]} ]' > "$TMPFILE"
jq "[ .[] | .labels = { \"hash\": \"$SPEC_HASH\" } ]" "$TMPFILE" | sponge "$TMPFILE"
jq '.[0].labels.role = "add"' "$TMPFILE" | sponge "$TMPFILE"
jq '.[1].labels.role = "get"' "$TMPFILE" | sponge "$TMPFILE"

mv -f "$TMPFILE" ./prom_end.json
rm -f "$TMPFILE"


echo "Adding:"
time iptb run 0 ipfs add "$DSET" -r -w -q --raw-leaves="$(geto rawleaves)" | tail -1 > "$TMPFILE"
OUT_HASH=$(cat "$TMPFILE")

echo "Getting:"
ODIR="$(mktemp -d -p "$WD" output.XXXXXXX)"
time iptb run 1 ipfs get -o "$ODIR" "$OUT_HASH"


# if run was successful, save the spec to a file with its hash

iptb stop
CLEAN_EXIT=1


