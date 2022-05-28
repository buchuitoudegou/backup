package common

import (
	"context"
	"fmt"
)

type Printer struct {
	printCh chan string
}

func NewPrinter() *Printer {
	return &Printer{
		printCh: make(chan string),
	}
}

func (p *Printer) Start(ctx context.Context) {
	for {
		select {
		case c := <-p.printCh:
			fmt.Printf("%s\n", c)
		case <-ctx.Done():
			return
		}
	}
}

func (p *Printer) Send(from string, content string) {
	s := fmt.Sprintf("%s: %s", from, content)
	p.printCh <- s
}

type GlobalContext struct {
	ctx     context.Context
	cancel  context.CancelFunc
	printer *Printer
}

func NewGlobalContext() *GlobalContext {
	ctx, cancel := context.WithCancel(context.Background())
	ret := &GlobalContext{
		ctx:     ctx,
		cancel:  cancel,
		printer: NewPrinter(),
	}
	go ret.printer.Start(ret.ctx)
	return ret
}

func (g *GlobalContext) Done() <-chan struct{} {
	return g.ctx.Done()
}

func (g *GlobalContext) Cancel() {
	g.cancel()
}

func (g *GlobalContext) Print(from string, content string) {
	g.printer.Send(from, content)
}
