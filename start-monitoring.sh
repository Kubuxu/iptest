#!/usr/bin/env bash
set -exuo pipefail
IFS=$'\n\t'

OLDWD=$(realpath .)
prometheus  -config.file prometheus.yml &
PromPID=$!

cd /usr/share/grafana # grafana has to be started in directory
sudo -g grafana -u grafana grafana-server --config="$OLDWD/grafana.ini" & # and it has to has access to its files
GrafPID=$!

wait $PromPID $GrafPID


