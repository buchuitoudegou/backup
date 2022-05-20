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
