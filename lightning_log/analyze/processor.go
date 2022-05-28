package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/buchuitoudegou/lightninglog/common"
)

type DiskQuotaContext struct {
	diskQuota   int
	falseCount  int
	trueCount   int
	diskSizes   []int
	memSizes    []int
	exceedSizes []int
}

func (d *DiskQuotaContext) serialize() string {
	lstIdx := len(d.diskSizes) - 1
	var hitRate float64
	if d.trueCount+d.falseCount > 0 {
		hitRate = float64(d.falseCount) / float64(d.trueCount+d.falseCount)
	}
	if lstIdx < 0 {
		if d.trueCount != 0 || d.falseCount != 0 {
			return fmt.Sprintf("hit rate: %.2f", hitRate)
		}
		return ""
	}
	total := d.diskSizes[lstIdx] + d.memSizes[lstIdx]
	var avgExceed int
	if len(d.exceedSizes) > 0 {
		sum := 0
		for i := range d.exceedSizes {
			sum += d.exceedSizes[i]
		}
		avgExceed = sum / len(d.exceedSizes)
	}
	return fmt.Sprintf("hit rate: %.2f, lastTotalSizeUsed: %d MB, avgExceedSize: %d MB", hitRate, (total >> 20), (avgExceed >> 20))
}

type DirSizeContext struct {
	path          string
	sizes         []int64
	checkInterval time.Duration
}

func (d *DirSizeContext) serialize() string {
	intervalInSecond := d.checkInterval.Seconds()
	speedSum := 0.0
	sizeSum := 0.0
	cnt := 0
	for i := 0; i < len(d.sizes); i++ {
		if i > 0 {
			if d.sizes[i] > d.sizes[i-1] {
				cnt++
				speedSum += float64(d.sizes[i]-d.sizes[i-1]) / intervalInSecond
			}
		}
		sizeSum += float64(d.sizes[i])
	}
	avgSpeed := int64(speedSum / float64(cnt))
	avgSize := int64(sizeSum / float64(len(d.sizes)))
	return fmt.Sprintf("avg speed: %d MB/s, avg size used: %dMB", (avgSpeed >> 20), (avgSize >> 20))
}

type LogStreamProcessor struct {
	diskQuotaCtx *DiskQuotaContext
	dirSizeCtx   *DirSizeContext
	deserializer logDeserializer

	ctx *common.GlobalContext

	logInfoRegexpr  *regexp.Regexp
	logInfoRegexpr2 *regexp.Regexp
	ifExit          *regexp.Regexp
}

func NewLogStreamProcessor(ctx *common.GlobalContext, dirPath string, c time.Duration, diskQuota int) *LogStreamProcessor {
	return &LogStreamProcessor{
		dirSizeCtx: &DirSizeContext{
			sizes:         make([]int64, 0),
			path:          dirPath,
			checkInterval: c,
		},
		diskQuotaCtx: &DiskQuotaContext{
			diskQuota: diskQuota,
		},
		ctx:             ctx,
		logInfoRegexpr:  regexp.MustCompile("disk quota exceeded.*"),
		logInfoRegexpr2: regexp.MustCompile("disk quota respected.*"),
		ifExit:          regexp.MustCompile("tidb lightning exit.*"),
	}
}

func (l *LogStreamProcessor) Init() {
	checkSize := func() int64 {
		size := int64(0)
		err := filepath.Walk(l.dirSizeCtx.path, func(_ string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if !info.IsDir() {
				size += info.Size()
			}
			return err
		})
		if err != nil {
			l.ctx.Print("[WARNING] check dir size", "unable to calculate size of the specified dir")
			return 0
		}
		return size
	}
	go func() {
		timer := time.NewTicker(l.dirSizeCtx.checkInterval)
		for {
			select {
			case <-timer.C:
				size := checkSize()
				l.dirSizeCtx.sizes = append(l.dirSizeCtx.sizes, size)
			case <-l.ctx.Done():
				l.ctx.Print("check dir size", "exit")
				return
			}
		}
	}()
}

func (l *LogStreamProcessor) Process(s string) string {
	strs := strings.Split(s, "\n")
	hasChange := false
	for _, str := range strs {
		ret := l.deserializer.deserialize(str)
		matched1, matched2 := l.logInfoRegexpr.Match([]byte(ret[logInfo])), l.logInfoRegexpr2.Match([]byte(ret[logInfo]))
		exit := l.ifExit.Match([]byte(ret[logInfo]))
		if exit {
			l.ctx.Print("exit", ret[logInfo])
			l.ctx.Print("final result", l.collectResult())
			l.ctx.Cancel()
			return ""
		}
		if matched1 || matched2 {
			hasChange = true
			diskSize, err := strconv.Atoi(ret["diskSize"])
			if err != nil {
				panic(err.Error())
			}
			memSize, err := strconv.Atoi(ret["memSize"])
			if err != nil {
				panic(err.Error())
			}
			l.diskQuotaCtx.diskSizes = append(l.diskQuotaCtx.diskSizes, diskSize)
			l.diskQuotaCtx.memSizes = append(l.diskQuotaCtx.memSizes, memSize)
		}
		if matched1 {
			length := len(l.diskQuotaCtx.diskSizes)
			lastDiskSize := l.diskQuotaCtx.diskSizes[length-1]
			lastMemSize := l.diskQuotaCtx.memSizes[length-1]
			l.diskQuotaCtx.exceedSizes = append(l.diskQuotaCtx.exceedSizes, (lastDiskSize+lastMemSize)-l.diskQuotaCtx.diskQuota)
			l.diskQuotaCtx.falseCount++
		}
		if matched2 {
			l.diskQuotaCtx.trueCount++
		}
	}
	if hasChange {
		return l.diskQuotaCtx.serialize()
	}
	return ""
}

func (l *LogStreamProcessor) collectResult() string {
	ret := "\n-------------------------------\n"
	ret += l.diskQuotaCtx.serialize()
	ret += "\n"
	ret += l.dirSizeCtx.serialize()
	ret += "\n-------------------------------\n"
	return ret
}
