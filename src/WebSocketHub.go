////////////////////////////////////////////////////////////////////////////////
// Manages all websocket connections.

package main

import (
	"encoding/binary"
	"github.com/gorilla/websocket"
	"time"
	"os"
	"strconv"
	"log"
)

////////////////////////////////////////////////////////////////////////////////
// Struct definition

type WebSocketHub struct {

	// List of clients
	clients map[*WebSocketClient]bool

	// Queues for client registration and deregistration
	reg   chan *WebSocketClient
	dereg chan *WebSocketClient

	// Pixels placed by clients
	// First 12 bits: x coord
	// Next 12 bits: y coord
	// Last 8 bits: color code
	placedPixels chan uint32

	// Current board
	board []byte

	// Map of changes to board yet to be applied
	// Key is 1D index, value is color code
	changes map[uint32]byte

	// Tickers to send out messages and make backups
	tickerUpdate *time.Ticker
	tickerBackup *time.Ticker

}

////////////////////////////////////////////////////////////////////////////////
// Constructor

// Initializes and runs a new web socket manager
func NewWebSocketHub () *WebSocketHub { 
	
	//==========================================================================
	// Initialize fields

	ret := &WebSocketHub {
		clients: make(map[*WebSocketClient]bool),
		reg: make(chan *WebSocketClient),
		dereg: make(chan *WebSocketClient),
		placedPixels: make(chan uint32),
		board: make([]byte, BOARD_WIDTH * BOARD_HEIGHT),
		changes: make(map[uint32]byte),
		tickerUpdate: nil,
		tickerBackup: nil,
	}

	//==========================================================================
	// Read the board into memory

	// Open current board file

	f, err := os.Open("./backups/current")

	if err != nil {
		// TODO
	}

	defer func() { if err = f.Close(); err != nil {
		// TODO
	} }()

	// Read into board variable

	_, err = f.Read(ret.board)

	if err != nil {
		// TODO
	}

	//==========================================================================
	// Run the hub's main loop

	go ret.run()

	//==========================================================================
	return ret

}

////////////////////////////////////////////////////////////////////////////////
// Public methods

//==============================================================================
func (this *WebSocketHub) GetInitializationMessage () *websocket.PreparedMessage {

	// Prepend the correct message type to the stored board
	msgraw := append( []byte{ MSGTYPE_HBOARD }, this.board... )

	// Use it to generate a new prepared message
	msgprep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msgraw )
	
		if err != nil {
			// TODO
			return nil
		}
	
	return msgprep

}

//==============================================================================
func (this *WebSocketHub) RequestRegistration (c *WebSocketClient) {
	this.reg <- c
}

//==============================================================================
func (this *WebSocketHub) RequestDeregistration (c *WebSocketClient) {
	this.dereg <- c
}

//==============================================================================
func (this *WebSocketHub) RequestPlacePixel (px uint32) {
	this.placedPixels <- px
}

////////////////////////////////////////////////////////////////////////////////
// Private methods

//==============================================================================
// Run the manager (designed to be called as a goroutine)
func (this *WebSocketHub) run () {

	//--------------------------------------------------------------------------
	// Initialization

	// Cleanup
	defer func() {
		this.tickerUpdate.Stop()
		this.tickerBackup.Stop()
	}()

	// Set up tickers
	// TODO constants
	this.tickerUpdate = time.NewTicker(TIMER_UPDATE_MS * time.Millisecond)
	this.tickerBackup = time.NewTicker(TIMER_BACKUP_MS * time.Millisecond)

	// Just a giant, infinitely-running loop
	// Handle all messages from all channels
	for { select {

		//----------------------------------------------------------------------
		// Process ticker messages

		// Send out board changes since last send tick to all clients
		case <- this.tickerUpdate.C:
			this.processUpdate()
		case <- this.tickerBackup.C:
			this.processUpdate()
			this.processBackup()

		//----------------------------------------------------------------------
		// Process registration-related requests
		
		case c := <- this.reg:
			this.register(c)
		case c := <- this.dereg:
			this.deregister(c)
		
		//----------------------------------------------------------------------
		// Process pixel placement

		case p := <- this.placedPixels:
			k, v := UnpackPixel2(p)
			this.changes[k] = v

	} }

}

//==============================================================================
// Update clients with board changes
func (this *WebSocketHub) processUpdate () {

	// Final message buffer
	msgraw := make([]byte, 1 + (4 * len(this.changes)))

	// Set message type
	msgraw[0] = 0x10

	// Build out message and update internal board state


	// k is index (packed x/y) -- v is color code
	i := 1; for k, v := range this.changes {
		binary.BigEndian.PutUint32( msgraw[i:i+4], PackPixel2(k, v) )
		this.board[k] = v
		i += 4
	}

	// Prepare message
	msgprep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msgraw )
log.Println(msgraw)

	if err != nil {
		// TODO
	}

	// TODO error handling

	// Send to all clients
	for c, _ := range this.clients {
		c.SendMessage(msgprep)
	}

	// Reset changes tracker
	this.changes = make(map[uint32]byte)

}

//==============================================================================
// Complete backup of board state
func (this *WebSocketHub) processBackup () {

	// Rename current backup of board
	os.Rename("./backups/current", "./backups/bu_" + strconv.Itoa((int)(time.Now().Unix())))

	// Write board variable as new current

	f, err := os.Open("./backups/current")

	if err != nil {
		// TODO
	}

	defer func() { if err = f.Close(); err != nil {
		// TODO
	} }()

	_, err = f.Write(this.board)

	if err != nil {
		// TODO
	}

}

//==============================================================================
// Register a new client
// Add the client to clients list
func (this *WebSocketHub) register (c *WebSocketClient) {
	this.clients[c] = true
}

//==============================================================================
// Unregister an existing client
// Terminate the client's connection and remove from clients list
func (this *WebSocketHub) deregister (c *WebSocketClient) {
	if _, exists := this.clients[c]; exists {
		//c.terminateConnection()
		delete(this.clients, c)
	}
}