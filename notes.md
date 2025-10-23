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