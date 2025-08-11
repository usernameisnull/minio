//go:build !windows
// +build !windows

// Copyright (c) 2015-2021 MinIO, Inc.
//
// This file is part of MinIO Object Storage stack
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

package disk

import (
	"syscall"
)

// SameDisk reports whether di1 and di2 describe the same disk.
// mabing: 获取的是 传入路径 所在文件系统的设备 ID，可以用它判断两个路径是不是在同一个挂载点上（同一个设备)
// disk1=/root/daocloud/minio/minio/mine/.verify-9970/1/1, disk2=/
// lsblk的等同命令
// lsblk -o MAJ:MIN,NAME -n
// 这里的st1.Dev需要如下处理能获得上面的lsblk的等同输出
// major := (st.Dev >> 8) & 0xfff
// minor := (st.Dev & 0xff) | ((st.Dev >> 12) & 0xfff00)
//
//8:0   sda
//8:16  sdb
//8:32  sdc
//8:48  sdd
func SameDisk(disk1, disk2 string) (bool, error) {
	st1 := syscall.Stat_t{}
	st2 := syscall.Stat_t{}

	if err := syscall.Stat(disk1, &st1); err != nil {
		return false, err
	}

	if err := syscall.Stat(disk2, &st2); err != nil {
		return false, err
	}

	return st1.Dev == st2.Dev, nil
}
