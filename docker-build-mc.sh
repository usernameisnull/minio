#!/bin/sh

set -eux

function _init() {
  ## 拉取最新的tag
  release=$(git describe --tags $(git rev-list --tags --max-count=1))
  if [ -z "$release" ]; then
    echo "No tags found"
    exit 1
  fi
  SUPPORTED_OSARCH="linux/amd64 linux/arm64"
  ## 从 GitHub 直接拉取指定 tag
  echo "Fetching release tag '$release' from  git@github.com:minio/mc.git ..."
  git fetch --tags  git@github.com:minio/mc.git "$release" || {
    echo "Failed to fetch tag '$release' from remote."
    exit 1
  }

  ## 检出该 tag
  git checkout "tags/$release" -b "build-$release" || {
    echo "Failed to checkout tag '$release'"
    exit 1
  }

  export release
  echo "Initialized for release: $release"
}

function _build() {
	local osarch=$1
	IFS=/ read -r -a arr <<<"$osarch"
	os="${arr[0]}"
	arch="${arr[1]}"

	# go build -trimpath to build the binary.
	export GOOS=$os
	export GOARCH=$arch
	LDFLAGS=$(go run buildscripts/gen-ldflags.go)
	go build -tags kqueue -trimpath --ldflags "${LDFLAGS}" -o ./mc-${os}-${arch}
}

function main() {
	echo "Builds for OS/Arch: ${SUPPORTED_OSARCH}"
	for each_osarch in ${SUPPORTED_OSARCH}; do
		_build "${each_osarch}"
	done
}

_init && _build "$@"