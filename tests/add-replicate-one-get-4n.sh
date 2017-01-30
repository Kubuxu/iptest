#!/usr/bin/env bash

IPTEST_NODES=4

iptest_nodes_roles() {
	case "$1" in
		0)	echo "adder"
			;;
		1)	echo "rep-1"
			;;
		2)	echo "rep-2"
			;;
		3)	echo "getter"
	esac
}



iptest_run() {
	DSET="$1"
	ODIR="$2"
	TMPF="$(mktemp)"

	echo "Adding:"
	SECONDS=0
	time iptb run 0 ipfs add "$DSET" -r -w -q --raw-leaves="$(geto rawleaves)" | tail -1 > "$TMPF"
	echo "Add took: $SECONDS seconds."
	OUT_HASH=$(cat "$TMPF")

	echo "Replicating:"
	SECONDS=0
	time iptb run 1 ipfs refs -r "$OUT_HASH" > /dev/null &
	REFS1=$!
	time iptb run 2 ipfs refs -r "$OUT_HASH" > /dev/null &
	REFS2=$!
	wait $REFS1 $REFS2
	echo "Replication to two peers took: $SECONDS seconds."


	SECONDS=0
	echo "Getting:"
	time iptb run 3 ipfs get -o "$ODIR" "$OUT_HASH"
	echo "Get took: $SECONDS seconds."

	rm -rf "$TMPF"
}
