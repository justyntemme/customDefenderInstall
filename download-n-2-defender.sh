#!/usr/bin/env bash
set -euo pipefail

versions=(
  34_03_138
  34_02_133
  34_01_132
)

for VERSION in "${versions[@]}"; do
  image="registry-auth.twistlock.com/tw_${TOKEN}/twistlock/defender:defender_${VERSION}"
  docker pull "${image}"
  docker save "${image}" | gzip > "defender_${VERSION}.tar.gz"
done
