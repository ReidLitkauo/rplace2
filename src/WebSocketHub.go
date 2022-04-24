////////////////////////////////////////////////////////////////////////////////
// Manages all websocket connections.

package main

import (
	"encoding/binary"
	"github.com/gorilla/websocket"
	"time"
	"os"
	"strconv"
	"github.com/rs/zerolog/log"
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

	// Map of usernames to timestamps for last pixel placed
	// Used to rate-limit accounts
	tsplaced map[string]int64

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
		tsplaced: make(map[string]int64),
		tickerUpdate: nil,
		tickerBackup: nil,
	}

	//==========================================================================
	// Read the board into memory

	// Open current board file
	f, err := os.Open("./backups/current")
	if err != nil { log.Panic().Err(err).Msg("Cannot open board file") }

	// Prepare for closure
	defer func() {
		err = f.Close()
		if err != nil { log.Error().Err(err).Msg("Unable to close current board file") }
	}()

	// Read into board variable
	_, err = f.Read(ret.board)
	if err != nil { log.Panic().Err(err).Msg("Unable to read current board file") }

	//==========================================================================
	// Run the hub's main loop

	go ret.run()

	//==========================================================================
	// Nothing to do here *blast off*

	log.Info().Msg("Websocket hub is set up")
	return ret

}

////////////////////////////////////////////////////////////////////////////////
// Public methods

//==============================================================================
func (this *WebSocketHub) GetInitializationMessage (authenticated bool) *websocket.PreparedMessage {

	// Determine correct message type to send
	msgtype := MSGTYPE_HBOARDANON
	if (authenticated) { msgtype = MSGTYPE_HBOARDAUTH }

	// Prepend the correct message type to the stored board
	msgraw := append( []byte{ byte(msgtype) }, this.board... )

	// Use it to generate a new prepared message
	msgprep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msgraw )
	if err != nil { log.Error().Err(err).Msg("Unable to generate initialization WS message") }
	
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
func (this *WebSocketHub) RequestPlacePixel (c *WebSocketClient, px uint32) bool {

	//--------------------------------------------------------------------------
	// Initialization

	// Get current time
	now := time.Now().Unix()

	//--------------------------------------------------------------------------
	// Rejection scenarios

	// Reject all pixels placed by non-authenticated users
	// ... how would we even get here? meh
	if c.Username == "" { return false }

	// Reject if request is being placed too soon after the last pixel placed
	// aka rate limiting
	if now < this.tsplaced[c.Username] + RATELIMIT_SEC { return false }

	//--------------------------------------------------------------------------
	// Approved

	// Set timestamp for last placed pixel
	this.tsplaced[c.Username] = now

	// Place pixel in queue
	this.placedPixels <- px

	return true

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

	//--------------------------------------------------------------------------
	// Initialization

	// Don't send anything if no changes made
	if len(this.changes) == 0 { return }

	// Final message buffer
	msgraw := make([]byte, 1 + (4 * len(this.changes)))

	// Set message type
	msgraw[0] = MSGTYPE_HUPDATE

	//--------------------------------------------------------------------------
	// Processing

	// Loop over all changes, build message and update board state at same time
	// k is index (packed x/y) -- v is color code
	i := 1; for k, v := range this.changes {
		binary.BigEndian.PutUint32( msgraw[i:i+4], PackPixel2(k, v) )
		this.board[k] = v
		i += 4
	}

	// Prepare message
	msgprep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msgraw )
	if err != nil { log.Error().Err(err).Msg("Unable to prepare update WS message") }

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

	// Grab a timestamp
	ts := strconv.Itoa((int)(time.Now().Unix()))

	// Rename current backup of board
	os.Rename("./backups/current", "./backups/bu_" + ts)

	// Open new current file for writing
	f, err := os.Create("./backups/current")
	if err != nil { log.Error().Err(err).Msg("Unable to create new backup file") }

	// Defer closure of current file
	defer func() {
		err = f.Close()
		if err != nil { log.Error().Err(err).Msg("Unable to close new current board file") }
	}()

	// Write new file
	_, err = f.Write(this.board)
	if err != nil { log.Error().Err(err).Msg("Unable to write contents of board to new current board file") }

	log.Info().Msgf("Backup created: %s", ts)

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
		//c.terminateConnection() // TODO is this necessary?
		delete(this.clients, c)
	}
}