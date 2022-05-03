//##############################################################################
// /src/WebSocketClient.go
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

//##############################################################################
// Struct definition

type WebSocketHub struct {

	////////////////////////////////////////////////////////////////////////////
	// Private fields

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

	// Images placed by clients
	// uint16 xcoord
	// uint16 ycoord
	// uint16 width
	// uint16 height
	// then raw color code data
	placedImages chan []byte

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

//##############################################################################
// Public methods

////////////////////////////////////////////////////////////////////////////////
// Constructor

func NewWebSocketHub () *WebSocketHub { 
	
	//==========================================================================
	// Initialize fields

	ret := &WebSocketHub {
		clients: make(map[*WebSocketClient]bool),
		reg: make(chan *WebSocketClient),
		dereg: make(chan *WebSocketClient),
		placedPixels: make(chan uint32),
		placedImages: make(chan []byte),
		board: make([]byte, (uint32)(g_cfg.Board.Width) * (uint32)(g_cfg.Board.Height)),
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

	return ret

}

////////////////////////////////////////////////////////////////////////////////
// Returns a list of messages a new client should send to its user

func (this *WebSocketHub) GetInitializationMessages (username string, role int) []*websocket.PreparedMessage {

	//==========================================================================
	// Initialization

	ret := make([]*websocket.PreparedMessage, 0)

	//==========================================================================
	// Prepare board message

	// Map role to message type
	msgboardtype := MSG_S_BOARDANON
	switch role {
		case ROLE_ADMN: msgboardtype = MSG_S_BOARDADMN
		case ROLE_AUTH: msgboardtype = MSG_S_BOARDAUTH
		case ROLE_BANN: msgboardtype = MSG_S_BOARDBANN
	}

	// Prepend the correct message type to the stored board
	msgboardraw := append( []byte{ byte(msgboardtype) }, this.board... )

	// Use it to generate a new prepared message
	msgboardprep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msgboardraw )
	if err != nil { log.Error().Err(err).Msg("Unable to generate initialization WS message") }

	ret = append(ret, msgboardprep)

	//==========================================================================
	// Prepare optional rate-limit message

	// Determine how much time is left in cooldown
	cooldown := this.tsplaced[username] + g_cfg.Pixel_rate_sec - time.Now().Unix()

	// If the user is authenitcated, and the user can't place a pixel quite yet
	if username != "" && cooldown > 0 {

		// Create raw message
		msgrateraw := make([]byte, 5)

		// Set message type
		msgrateraw[0] = MSG_S_COOLDOWN

		// Write cooldown into message
		binary.BigEndian.PutUint32( msgrateraw[1:5], uint32(cooldown) )

		// Generate new prepared message
		msgrateprep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msgrateraw )
		if err != nil { log.Error().Err(err).Msg("Unable to generate initialization WS message") }
	
		// Send out with other messages
		ret = append(ret, msgrateprep)

	}

	//==========================================================================
	// Send out init messages

	return ret

}

////////////////////////////////////////////////////////////////////////////////
// Registration and deregistration

func (this *WebSocketHub) RequestRegistration (c *WebSocketClient) {
	this.reg <- c
}

func (this *WebSocketHub) RequestDeregistration (c *WebSocketClient) {
	this.dereg <- c
}

////////////////////////////////////////////////////////////////////////////////
// Request accepting a message
// A client calls this method when it has a message it wants to send to the hub

func (this *WebSocketHub) RequestAcceptMessage (c *WebSocketClient, msg []byte) bool {

	//==========================================================================
	// Initialization

	// Get current time
	now := time.Now().Unix()

	// Get message type
	msgtype := msg[0]

	switch msgtype {

		//======================================================================
		// Pixel placement

		case MSG_C_PLACE:

			//------------------------------------------------------------------
			// Rejection scenarios

			// Reject all from anon and banned users
			if c.Role == ROLE_ANON || c.Role == ROLE_BANN { return false }

			// Enforce rate limiting for normal users
			if tsplaced, ok := this.tsplaced[c.Username]; ok && c.Role == ROLE_AUTH {
				if now < tsplaced + g_cfg.Pixel_rate_sec {
					return false
			} }

			//------------------------------------------------------------------
			// Processing

			// Extract packed pixel from message
			px := binary.BigEndian.Uint32(msg[1:5])

			//------------------------------------------------------------------
			// Approval

			// Set new timestamp for last placed pixel
			this.tsplaced[c.Username] = now

			// Place pixel into queue
			this.placedPixels <- px

			return true
		
		//======================================================================
		// Image placment

		case MSG_C_IMAGE:

			//------------------------------------------------------------------
			// Rejection scenarios
			
			// ADMN only! Reject all other user roles
			if c.Role != ROLE_ADMN { return false }

			//------------------------------------------------------------------
			// Approval

			// Place image into queue
			this.placedImages <- msg[1:]

			return true

		//======================================================================
		// Unknown message type
		
		default: return false

	}

}

//##############################################################################
// Private methods

////////////////////////////////////////////////////////////////////////////////
// GOROUTINE Handle all messages

func (this *WebSocketHub) run () {

	//==========================================================================
	// Initialization

	// Cleanup
	defer func() {
		this.tickerUpdate.Stop()
		this.tickerBackup.Stop()
	}()

	// Set up tickers
	this.tickerUpdate = time.NewTicker(time.Duration(g_cfg.Timers.Update_ms) * time.Millisecond)
	this.tickerBackup = time.NewTicker(time.Duration(g_cfg.Timers.Backup_ms) * time.Millisecond)

	// Just a giant, infinitely-running loop
	// Handle all messages from all channels
	for { select {

		//======================================================================
		// Process ticker messages

		// Send out board changes since last send tick to all clients
		case <- this.tickerUpdate.C:
			this.processUpdate()
		case <- this.tickerBackup.C:
			this.processUpdate()
			this.processBackup()

		//======================================================================
		// Process registration-related requests
		
		case c := <- this.reg:
			this.register(c)
		case c := <- this.dereg:
			this.deregister(c)
		
		//======================================================================
		// Process pixel placement

		case p := <- this.placedPixels:

			//------------------------------------------------------------------
			// Initialization

			// Grab key (index) and value (color code) from pixel
			k, v := UnpackPixel2(p)

			//------------------------------------------------------------------
			// Validation

			// Key is out of range
			if k >= (uint32)(len(this.board)) { break }

			// Value is invalid
			if v < 0 || v >= g_cfg.Board.Colors { break }
			
			//------------------------------------------------------------------
			// Execution

			// Apply pixel to changes
			this.changes[k] = v
		
		//======================================================================
		// Process image placement

		case msg := <- this.placedImages:

			//------------------------------------------------------------------
			// Initialization

			// Grab x/y/w/h
			x := binary.BigEndian.Uint16(msg[0:2])
			y := binary.BigEndian.Uint16(msg[2:4])
			w := binary.BigEndian.Uint16(msg[4:6])
			h := binary.BigEndian.Uint16(msg[6:8])

			//------------------------------------------------------------------
			// Validation

			// Ensure image fits entirely on image
			if x < 0 || (uint16)(x + w) >= g_cfg.Board.Width  { break }
			if y < 0 || (uint16)(y + h) >= g_cfg.Board.Height { break }

			// Ensure we have exactly enough data associated with the image
			if (uint16)(len(msg)) != 8 + (w * h) { break }

			//------------------------------------------------------------------
			// Execution

			// Iterate over the image's rows, then its pixels
			for yi := (uint16)(0); yi < h; yi++ { for xi := (uint16)(0); xi < w; xi++ {

				// Get image space & board space coords
				ii :=           xi      +            (yi       *          w)
				bi := ((uint32)(xi + x)) + (((uint32)(yi + y)) * (uint32)(g_cfg.Board.Width))

				// Get color code
				cc := msg[8 + ii]

				// Skip all out-of-bounds colors
				if cc >= g_cfg.Board.Colors { continue }

				// Place into changes
				this.changes[bi] = cc

			} }

	} }

}

////////////////////////////////////////////////////////////////////////////////
// Update clients with board changes

func (this *WebSocketHub) processUpdate () {

	//==========================================================================
	// Initialization

	// Don't send anything if no changes made
	if len(this.changes) == 0 { return }

	// Final message buffer
	msgraw := make([]byte, 1 + (4 * len(this.changes)))

	// Set message type
	msgraw[0] = MSG_S_UPDATE

	//==========================================================================
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

////////////////////////////////////////////////////////////////////////////////
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

////////////////////////////////////////////////////////////////////////////////
// Register / deregister

// Add a new client to the clients list
func (this *WebSocketHub) register (c *WebSocketClient) {
	this.clients[c] = true
}

// Terminate a client's connection and remove from clients list
func (this *WebSocketHub) deregister (c *WebSocketClient) {
	if _, exists := this.clients[c]; exists {
		//c.terminateConnection() // TODO is this necessary?
		delete(this.clients, c)
	}
}

