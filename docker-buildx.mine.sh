#!/bin/sh

set -eux

function _init() {
	## 参数：release tag 名称
	release="$1"
	if [ -z "$release" ]; then
		echo "Usage: _init <release-tag>"
		exit 1
	fi

	## 所有二进制为静态编译，禁用 CGO
	export CGO_ENABLED=0

	## 支持的 OS/ARCH 组合
	SUPPORTED_OSARCH="linux/amd64 linux/arm64"

	## 从 GitHub 直接拉取指定 tag
	echo "Fetching release tag '$release' from git@github.com:minio/minio.git ..."
	git fetch --tags git@github.com:minio/minio.git "$release" || {
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
	package=$(go list -f '{{.ImportPath}}')
	printf -- "--> %15s:%s\n" "${osarch}" "${package}"

	# go build -trimpath to build the binary.
	export GOOS=$os
	export GOARCH=$arch
	export MINIO_RELEASE=RELEASE
	LDFLAGS=$(go run buildscripts/gen-ldflags.go)
	go build -tags kqueue -trimpath --ldflags "${LDFLAGS}" -o ./minio-${os}-${arch}
}

function main() {
	echo "Build for OS/Arch: ${SUPPORTED_OSARCH}"
	for each_osarch in ${SUPPORTED_OSARCH}; do
		_build "${each_osarch}"
	done
}

_init "$@" && main "$@"