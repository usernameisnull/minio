#!/bin/bash -e
#

set -E
set -o pipefail

if [ ! -x "$PWD/minio" ]; then
	echo "minio executable binary not found in current directory"
	exit 1
fi

# mabing: $RANDOM 是 Bash shell 的内置变量。
WORK_DIR="$PWD/.verify-$RANDOM"
MINIO_CONFIG_DIR="$WORK_DIR/.minio"
MINIO=("$PWD/minio" --config-dir "$MINIO_CONFIG_DIR" server)
GOPATH=/tmp/gopath

function start_minio_3_node() {
	for i in $(seq 1 3); do
		rm "${WORK_DIR}/dist-minio-server$i.log"
	done

	export MINIO_ROOT_USER=minio
	export MINIO_ROOT_PASSWORD=minio123
	# mabing: 这个环境变量可以手动指定? https://github.com/minio/minio/discussions/20311
	export MINIO_ERASURE_SET_DRIVE_COUNT=6
	# mabing: 这个环境变量干啥?
	export MINIO_CI_CD=1

	first_time=$(find ${WORK_DIR}/ | grep format.json | wc -l)

	start_port=$1
	args=""
	for d in $(seq 1 3 5); do
		args="$args http://127.0.0.1:$((start_port + 1))${WORK_DIR}/1/${d}/ http://127.0.0.1:$((start_port + 2))${WORK_DIR}/2/${d}/ http://127.0.0.1:$((start_port + 3))${WORK_DIR}/3/${d}/ "
		d=$((d + 1))
		args="$args http://127.0.0.1:$((start_port + 1))${WORK_DIR}/1/${d}/ http://127.0.0.1:$((start_port + 2))${WORK_DIR}/2/${d}/ http://127.0.0.1:$((start_port + 3))${WORK_DIR}/3/${d}/ "
	done

	"${MINIO[@]}" --address ":$((start_port + 1))" $args >"${WORK_DIR}/dist-minio-server1.log" 2>&1 &
	# mabing: 在 Bash 中，$! 是一个特殊变量，保存最近一个在后台运行的进程的 PID
	pid1=$!
	disown ${pid1}

	"${MINIO[@]}" --address ":$((start_port + 2))" $args >"${WORK_DIR}/dist-minio-server2.log" 2>&1 &
	pid2=$!
	disown $pid2

	"${MINIO[@]}" --address ":$((start_port + 3))" $args >"${WORK_DIR}/dist-minio-server3.log" 2>&1 &
	pid3=$!
	disown $pid3

	# mabing: 在 MinIO 中，MC_HOST_ 前缀的环境变量用于配置 MinIO 客户端 (mc) 的别名 (alias)。这个应该是在mc的代码里实现的逻辑: https://github.com/usernameisnull/mc/blob/5bb5df85e222e84505c4f30490bcb43739cee74d/cmd/config.go#L269
	export MC_HOST_myminio="http://minio:minio123@127.0.0.1:$((start_port + 1))"
	# mabing: 如果命令在 15 分钟内没有完成，timeout 会终止该命令, 如果前面的命令执行失败（返回非零退出码），则执行 fail 函数
	timeout 15m /tmp/mc ready myminio || fail

	[ ${first_time} -eq 0 ] && upload_objects
	[ ${first_time} -ne 0 ] && sleep 120

	if ! ps -p $pid1 1>&2 >/dev/null; then
		echo "minio server 1 is not running" && fail
	fi

	if ! ps -p $pid2 1>&2 >/dev/null; then
		echo "minio server 2 is not running" && fail
	fi

	if ! ps -p $pid3 1>&2 >/dev/null; then
		echo "minio server 3 is not running" && fail
	fi

	if ! pkill minio; then
		fail
	fi

	sleep 1
	if pgrep minio; then
		# forcibly killing, to proceed further properly.
		if ! pkill -9 minio; then
			echo "no minio process running anymore, proceed."
		fi
	fi
}

function check_heal() {
	if ! grep -q 'API:' ${WORK_DIR}/dist-minio-*.log; then
		return 1
	fi

	for ((i = 0; i < 20; i++)); do
		test -f ${WORK_DIR}/$1/1/.minio.sys/format.json
		v1=$?
		nextInES=$(($1 + 1)) && [ $nextInES -gt 3 ] && nextInES=1
		foundFiles1=$(find ${WORK_DIR}/$1/1/ | grep -v .minio.sys | grep xl.meta | wc -l)
		foundFiles2=$(find ${WORK_DIR}/$nextInES/1/ | grep -v .minio.sys | grep xl.meta | wc -l)
		test $foundFiles1 -eq $foundFiles2
		v2=$?
		[ $v1 == 0 -a $v2 == 0 ] && return 0
		sleep 10
	done
	return 1
}

function purge() {
	rm -rf "$1"
}

function fail() {
	for i in $(seq 1 3); do
		echo "server$i log:"
		cat "${WORK_DIR}/dist-minio-server$i.log"
	done
	pkill -9 minio
	echo "FAILED"
	purge "$WORK_DIR"
	exit 1
}

function __init__() {
	echo "Initializing environment"
	mkdir -p "$WORK_DIR"
	mkdir -p "$MINIO_CONFIG_DIR"

	## version is purposefully set to '3' for minio to migrate configuration file
	echo '{"version": "3", "credential": {"accessKey": "minio", "secretKey": "minio123"}, "region": "us-east-1"}' >"$MINIO_CONFIG_DIR/config.json"

	if [ ! -f /tmp/mc ]; then
		wget --quiet -O /tmp/mc https://dl.minio.io/client/mc/release/linux-amd64/mc &&
			chmod +x /tmp/mc
	fi
}

function upload_objects() {
	/tmp/mc mb myminio/testbucket/
	for ((i = 0; i < 20; i++)); do
		echo "my content" | /tmp/mc pipe myminio/testbucket/file-$i
	done
}

function perform_test() {
	start_port=$2

	start_minio_3_node $start_port

	echo "Testing Distributed Erasure setup healing of drives"
	echo "Remove the contents of the disks belonging to '${1}' node"

	rm -rf ${WORK_DIR}/${1}/*/

	set -x
	start_minio_3_node $start_port

	check_heal ${1}
	rv=$?
	if [ "$rv" == "1" ]; then
		fail
	fi
}

function main() {
	# use same ports for all tests
	# mabing: 随机选择一个端口号
	start_port=$(shuf -i 10000-65000 -n 1)

	perform_test "2" ${start_port}
	perform_test "1" ${start_port}
	perform_test "3" ${start_port}
}

(__init__ "$@" && main "$@")
rv=$?
purge "$WORK_DIR"
exit "$rv"
