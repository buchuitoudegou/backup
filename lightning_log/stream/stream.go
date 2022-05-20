package stream

type DataStream interface {
	Process(p Processor)
	Execute()
	Print()
}

type Processor = func(string) string
