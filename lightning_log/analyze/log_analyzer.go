package main

import (
	"strings"
)

const (
	blockStart       = '['
	blockEnd         = ']'
	infoIndicator    = '"'
	contentIndicator = '='
)

type logType = int

const (
	normal logType = iota
	info
	content
)

const logInfo = "logInfo"

type logDeserializer struct{}

func (l *logDeserializer) deserialize(rawLog string) map[string]string {
	lt := normal
	ret := make(map[string]string)
	temp := ""
	for i := range rawLog {
		switch rawLog[i] {
		case blockStart:
			temp = ""
		case blockEnd:
			appendResult(ret, temp, lt)
			temp = ""
		case infoIndicator:
			lt = info
		case contentIndicator:
			lt = content
			temp += string(rawLog[i])
		default:
			temp += string(rawLog[i])
		}
	}
	return ret
}

func appendResult(ret map[string]string, str string, lt logType) {
	if lt == normal {
		return
	}
	switch lt {
	case info:
		ret[logInfo] = str
	case content:
		kvs := strings.Split(str, string(contentIndicator))
		if len(kvs) == 2 {
			ret[kvs[0]] = kvs[1]
		}
	}
}
