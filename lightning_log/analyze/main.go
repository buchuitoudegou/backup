package main

import (
	"time"

	"github.com/buchuitoudegou/lightninglog/common"
	"github.com/buchuitoudegou/lightninglog/stream"
)

const (
	GB = 1073741824
	MB = 1048576
	KB = 102
)

func main() {
	globalCtx := common.NewGlobalContext()
	f := stream.NewFileStream(globalCtx, "/home/tidb-lightning.log")
	f.Process(NewLogStreamProcessor(globalCtx, "/tmp/sst", 2*time.Second, 10*GB))
	f.Print()
	f.Execute()
}
