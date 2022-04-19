////////////////////////////////////////////////////////////////////////////////
// Handles a single client connection.

package main

import (
	"log"
	"net/http"
	"encoding/binary"
	"github.com/gorilla/websocket"
)

////////////////////////////////////////////////////////////////////////////////
// Struct definition

type WebSocketClient struct {

	// The hub this client is connected to
	wsh *WebSocketHub

	// The websocket connection
	ws *websocket.Conn

	// Channel of messages to send to this client
	send chan *websocket.PreparedMessage

}

////////////////////////////////////////////////////////////////////////////////
// Constructor

func NewWebSocketClient (wsh *WebSocketHub, w http.ResponseWriter, r *http.Request) *WebSocketClient {

	// Upgrade the passed HTTP connection into a WS connection
	// TODO move these constants to a better spot, constants.go
	upgrader := websocket.Upgrader {
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
	}

	ws, err := upgrader.Upgrade(w, r, nil)

	// Encountered some sort of error during the upgrade process.
	if err != nil {
		log.Println(err)
		return nil
	}

	// Set ws connection parameters
	ws.SetReadLimit(64)

	// Create the new WSClient object
	wsc := &WebSocketClient{
		wsh: wsh,
		ws: ws,
		send: make(chan *websocket.PreparedMessage, 256),
	}	

	// Request registration to the hub
	wsh.RequestRegistration(wsc)

	// Run send/recv goroutines
	go wsc.handleSend()
	go wsc.handleRecv()

	// Send initialization message
	wsc.SendMessage(wsh.GetInitializationMessage())

	// Success
	return wsc

}

////////////////////////////////////////////////////////////////////////////////
// Public methods

// Send a message to this client
func (this *WebSocketClient) SendMessage (m *websocket.PreparedMessage) {
	this.send <- m
}

////////////////////////////////////////////////////////////////////////////////
// Private methods

// Send out all queued messages
// Run as goroutine
func (this *WebSocketClient) handleSend () {

	// Cleanup
	defer func() {
		this.wsh.RequestDeregistration(this)
		this.ws.Close()
	}()

	// Main handling loop
	for { select {

	case msg := <- this.send:

		this.ws.WritePreparedMessage(msg)

	} }

}

func (this *WebSocketClient) handleRecv () {

	// Cleanup
	defer func() {
		this.wsh.RequestDeregistration(this)
		this.ws.Close()
	}()

	// Main handling loop
	for {

		// Wait for the next message
		_, msg, err := this.ws.ReadMessage()

		if err != nil {
			log.Println(err)
			break
		}

		// Process different types of messages
		switch msg[0] {

			// Place a pixel
			case 0x20:

				// Convert the next four bytes into an encoded uint32
				// and add to the hub's queue
				this.wsh.RequestPlacePixel(binary.BigEndian.Uint32(msg[1:5]))

		}

	}

}