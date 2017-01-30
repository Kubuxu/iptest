#!/usr/bin/env bash

IPTEST_NODES=2

iptest_nodes_roles() {
	case "$1" in
		0)
			echo "adder"
			;;
		1)	echo "getter"
	esac
}



iptest_run() {
	DSET="$1"
	ODIR="$2"
	TMPF="$(mktemp)"

	echo "Adding:"
	time iptb run 0 ipfs add "$DSET" -r -w -q --raw-leaves="$(geto rawleaves)" | tail -1 > "$TMPF"
	OUT_HASH=$(cat "$TMPF")

	echo "Getting:"
	time iptb run 1 ipfs get -o "$ODIR" "$OUT_HASH"

	rm -rf "$TMPF"


}
