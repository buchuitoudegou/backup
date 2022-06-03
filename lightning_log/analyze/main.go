package main

import (
	"errors"
	"os"
	"strconv"
	"time"

	"github.com/buchuitoudegou/lightninglog/common"
	"github.com/buchuitoudegou/lightninglog/stream"
	"github.com/spf13/cobra"
)

const (
	GB = 1073741824
	MB = 1048576
	KB = 102
)

var str2Unit = map[string]int{
	"GB": GB,
	"MB": MB,
	"KB": KB,
}

func NewDiskQuotaCommand() *cobra.Command {
	diskQuotaCommand := &cobra.Command{
		Short: "analyze disk quota log",
		RunE: func(cmd *cobra.Command, _ []string) error {
			diskQuota, err := cmd.Flags().GetString("disk-quota")
			if err != nil {
				return err
			}
			logfile, err := cmd.Flags().GetString("log")
			if err != nil {
				return err
			}
			suffixIdx := len(diskQuota) - 2
			if suffixIdx <= 0 {
				panic("unknown disk quota: " + diskQuota)
			}
			numStr := diskQuota[:suffixIdx]
			unit := diskQuota[suffixIdx:]
			num, err := strconv.Atoi(numStr)
			if err != nil {
				return err
			}
			if _, ok := str2Unit[unit]; !ok {
				return errors.New("unknown unit: " + unit)
			}
			startAnalyze(str2Unit[unit]*num, logfile)
			return nil
		},
	}
	diskQuotaCommand.Flags().String("disk-quota", "", "setting disk-quota")
	diskQuotaCommand.Flags().String("log", "", "setting log-file to monitor")
	return diskQuotaCommand
}

func startAnalyze(diskQuota int, logfile string) {
	globalCtx := common.NewGlobalContext()
	f := stream.NewFileStream(globalCtx, logfile)
	f.Process(NewLogStreamProcessor(globalCtx, "/tmp/sst", 2*time.Second, diskQuota))
	f.Print()
	f.Execute()
}

func main() {
	rootCmd := NewDiskQuotaCommand()
	args := os.Args[1:]
	rootCmd.SetArgs(args)
	rootCmd.Execute()
}
