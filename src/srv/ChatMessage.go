//##############################################################################
// /src/srv/ChatMessage.go
// TODO prettify

package main

import (
	"math/rand"
)

type ChatMessage struct {

	Msg string      `json:"msg"`
	Lang string     `json:"lang"`
	Username string `json:"user"`
	Role int        `json:"role"`
	Id int          `json:"id"`

}

func NewChatMessage (msg string, lang string, username string, role int) *ChatMessage {
	return &ChatMessage{ msg, lang, username, role, rand.Intn(0x7FFFFFFF) }
}