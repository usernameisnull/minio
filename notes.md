## 唯二的命令: server, fmt-gen
- server: 是用来启动minio服务的
- fmt-gen: 用来生成format.json

## trie是字典树
在`func newApp(name string) *cli.App {}`用到, 用来保存命令和子命令  
- minio/pkg这个库里的: git@github.com:minio/pkg.git

## 调用serverMain的时候,传入的ctx
- 在github.com/minio/cli里的方法`func (a *App) Run(arguments []string) (err error) {}` // app.go
  初始化context := NewContext(a, set, nil)
  - func (c Command) Run(ctx *Context) (err error) {} // command.go
    再次设置了context := NewContext(ctx.App, set, ctx) 这里的ctx是作为parentContext的
    - func HandleAction(action interface{}, context *Context) (err error) {} // app.go
      ```go
        else if a, ok := action.(func(*Context)); ok {
          a(context)
          return nil
      ```
      
## format.json
cmd/format-erasure.go:93, 
- 结构体: type formatErasureV2 struct {} 
- 函数: func newFormatErasureV3(numSets int, setLen int) *formatErasureV3 {}
- initFormatErasure把format.json写入磁盘?

## minio的github仓库变成source only了
不再提供镜像了: https://github.com/minio/minio/issues/21647
替代的下载: https://github.com/CloudPirates-io/helm-charts/issues/441

## 镜像打包
docker-buildx.sh里有这么一句: `go build -tags kqueue -trimpath`, go help build的输出如下: 
```txt
-tags tag,list
    a comma-separated list of additional build tags to consider satisfied
    during the build. For more information about build tags, see
    'go help buildconstraint'. (Earlier versions of Go used a
    space-separated list, and that form is deprecated but still recognized.)
-trimpath
    remove all file system paths from the resulting executable.
    Instead of absolute file system paths, the recorded file names
    will begin either a module path@version (when using modules),
    or a plain import path (when using the standard library, or GOPATH).
```
### kqueue
这个kqueue的tag在minio的源码里没有, 但是在依赖里有:  
```bash
go mod tidy && go mod vendor
grep kqueue . -R|grep build
```
### trimpath
会把 Go [编译时的本地绝对路径去掉]()，改成模块路径（或导入路径），以避免暴露构建环境并提升构建可重现性。

### 如何本地打镜像
这个仓库没有给出如何完整的打包镜像的流水线, 根据[docker hub](https://hub.docker.com/layers/minio/minio/RELEASE.2025-09-07T16-13-09Z/images/sha256-a1a8bd4ac40ad7881a245bab97323e18f971e4d4cba2c2007ec1bedd21cbaba2)   
上的image layers, 可以知道用的Dockerfile是[Dockerfile.release](Dockerfile.release), 现在没有minio的二进制可下载, 需要用docker-buildx.sh打包二进制, 同时需要修改Dockerfile.release   
在新的项目里打包: build-minio-image
- docker-buildx.sh
- Dockerfile.release

## console
UI所在的仓库: https://github.com/minio/object-browser

### 移除UI里的管理员功能
https://github.com/minio/object-browser/pull/3509

### 集成到minio的源里
因为这个仓库有go代码, minio的仓库直接在go.mod里引用了这个仓库
https://github.com/usernameisnull/minio/blob/d45c375dabea34b1b2734a79880e1e02f41183eb/go.mod#L54
```txt
github.com/minio/console v1.7.7-0.20250905210349-2017f33b26e1
```

## TODO
每次minio的仓库有新的tag,github自动打包