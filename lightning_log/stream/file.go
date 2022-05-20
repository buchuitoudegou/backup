package stream

import (
	"context"
	"os"
	"sync"

	"github.com/buchuitoudegou/lightninglog/common"
	"github.com/fsnotify/fsnotify"
)

type FileStream struct {
	path       string
	offset     uint64
	sink       chan string
	source     chan string
	fd         *os.File
	processors []Processor
	printer    *common.Printer
	ctx        context.Context
}

func NewFileStream(ctx context.Context, p string, printer *common.Printer) DataStream {
	fd, err := os.Open(p)
	if err != nil {
		panic(err.Error())
	}
	return &FileStream{
		path:       p,
		fd:         fd,
		sink:       make(chan string),
		source:     make(chan string),
		processors: make([]Processor, 0),
		printer:    printer,
		ctx:        ctx,
	}
}

func (f *FileStream) Process(p Processor) {
	f.processors = append(f.processors, p)
}

func (f *FileStream) Execute() {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		panic("new watcher: " + err.Error())
	}
	defer watcher.Close()

	wg := sync.WaitGroup{}
	wg.Add(2)
	// read from file (as source)
	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}
				if event.Op&fsnotify.Write == fsnotify.Write {
					f.loadDiff()
				}
			case <-watcher.Errors:
				wg.Done()
				return
			case <-f.ctx.Done():
				wg.Done()
				return
			}
		}
	}()
	// process
	go func() {
		for {
			select {
			case str := <-f.source:
				temp := str
				// fmt.Printf("str: %s\n", str)
				for _, p := range f.processors {
					temp = p(temp)
				}
				// fmt.Printf("temp: %s, processors: %d\n", temp, len(f.processors))
				if temp == "" {
					break
				}
				f.sink <- temp
			case <-f.ctx.Done():
				wg.Done()
				return
			}
		}
	}()
	err = watcher.Add(f.path)
	if err != nil {
		panic("add watcher: " + err.Error())
	}
	wg.Wait()
}

func (f *FileStream) loadDiff() {
	_, err := f.fd.Seek(int64(f.offset), 0)
	if err != nil {
		panic("seek: " + err.Error())
	}
	buffer := make([]byte, 100000) // 100 KB
	byteRead, err := f.fd.Read(buffer)
	if err != nil {
		// fmt.Printf("read error: " + err.Error())
		return
	}
	f.offset += uint64(byteRead)
	f.source <- string(buffer)
}

func (f *FileStream) Print() {
	for {
		select {
		case ret := <-f.sink:
			f.printer.Send("changes", ret)
		case <-f.ctx.Done():
			return
		}
	}
}
