package main

import (
	"context"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/buchuitoudegou/lightninglog/common"
	"github.com/buchuitoudegou/lightninglog/stream"
)

type DiskQuotaContext struct {
	falseCount int
	trueCount  int
	diskSizes  []int
	memSizes   []int
}

func (d *DiskQuotaContext) serialize() string {
	lstIdx := len(d.diskSizes) - 1
	if lstIdx < 0 {
		if d.trueCount != 0 || d.falseCount != 0 {
			return fmt.Sprintf("hit rate: %.2f", float64(d.falseCount)/float64(d.trueCount+d.falseCount))
		}
		return ""
	}
	total := d.diskSizes[lstIdx] + d.memSizes[lstIdx]
	return fmt.Sprintf("hit rate: %.2f, lastTotalSizeUsed: %d MB", float64(d.falseCount)/float64(d.trueCount+d.falseCount), (total >> 20))
}

type DirSizeContext struct {
	size          int
	checkCount    int
	checkInterval time.Duration
}

func main() {
	globalCtx, cancel := context.WithCancel(context.Background())
	printer := common.NewPrinter()
	go printer.Start(globalCtx)
	f := stream.NewFileStream(globalCtx, "/home/tidb-lightning.log", printer)
	l := logDeserializer{}
	logInfoRegexpr := regexp.MustCompile("disk quota exceeded.*")
	logInfoRegexpr2 := regexp.MustCompile("disk quota respected.*")
	ifExit := regexp.MustCompile("tidb lightning exit.*")
	ctx := DiskQuotaContext{}
	f.Process(func(s string) string {
		strs := strings.Split(s, "\n")
		for _, str := range strs {
			ret := l.deserialize(str)
			matched1, matched2 := logInfoRegexpr.Match([]byte(ret[logInfo])), logInfoRegexpr2.Match([]byte(ret[logInfo]))
			exit := ifExit.Match([]byte(ret[logInfo]))
			if exit {
				printer.Send("exit", ret[logInfo])
				cancel()
				return ""
			}
			if matched1 || matched2 {
				diskSize, err := strconv.Atoi(ret["diskSize"])
				if err != nil {
					panic(err.Error())
				}
				memSize, err := strconv.Atoi(ret["memSize"])
				if err != nil {
					panic(err.Error())
				}
				ctx.diskSizes = append(ctx.diskSizes, diskSize)
				ctx.memSizes = append(ctx.memSizes, memSize)
			}
			if matched1 {
				ctx.falseCount++
			}
			if matched2 {
				ctx.trueCount++
			}
		}
		return ctx.serialize()
	})
	go f.Print()
	f.Execute()
}
