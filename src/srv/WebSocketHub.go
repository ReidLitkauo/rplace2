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
	"encoding/json"
	"golang.org/x/exp/slices"
	"math"
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

	// Chat messages sent by users
	placedChats chan *ChatMessage

	// History of sent chats
	// Oldest is at position 0 / Newest is at the end
	chatHistory []*ChatMessage

	// List of chats to send out to clients
	// Only done once per update cycle
	// Oldest is at position 0 / Newest is at the end
	chatsToSend []*ChatMessage

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
		placedChats: make(chan *ChatMessage),
		chatHistory: make([]*ChatMessage, 0),
		chatsToSend: make([]*ChatMessage, 0),
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

	// New scopes are nice, glad all curly braces establish new scopes
	{

		// Map role to message type
		msg_type := MSG_S_BOARDANON // Default
		switch role {
			case ROLE_ADMN: msg_type = MSG_S_BOARDADMN
			case ROLE_AUTH: msg_type = MSG_S_BOARDAUTH
			case ROLE_BANN: msg_type = MSG_S_BOARDBANN
		}

		// Prepend the correct message type to the stored board
		msg_raw := append( []byte{ byte(msg_type) }, this.board... )

		// Use it to generate a new prepared message
		msg_prep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msg_raw )
		if err != nil { log.Error().Err(err).Msg("Unable to generate initialization WS message") }

		// Add to the list
		ret = append(ret, msg_prep)

	}

	//==========================================================================
	// Prepare optional user settings message

	// Only for logged-in users!
	if role == ROLE_ADMN || role == ROLE_AUTH {

		// Message structure
		type msg_settings struct {
			Username string `json:"user"`
			Role     int    `json:"role"`
		}

		// Create a new filled-out structure
		msg_struct := msg_settings{username, role}

		// Convert to JSON
		// No errors should be emitted by this function...
		// We are not marshaling any unsupported types or invalid values.
		msg_json, _ := json.Marshal(msg_struct)

		// Prepend message type to the JSON
		msg_raw := append( []byte{MSG_S_USERINFO}, msg_json... )

		// Create prepared message
		msg_prep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msg_raw )
		if err != nil { log.Error().Err(err).Msg("Unable to generate initialization WS message") }

		// Done with this message
		ret = append(ret, msg_prep)

	}

	//==========================================================================
	// Prepare optional rate-limit message

	// Determine how much time is left in cooldown
	cooldown := this.tsplaced[username] + g_cfg.Pixel_rate_sec - time.Now().Unix()

	// If the user is authenitcated, and the user can't place a pixel quite yet
	if role == ROLE_AUTH && cooldown > 0 {

		// Create raw message
		msg_raw := make([]byte, 5)

		// Set message type
		msg_raw[0] = MSG_S_COOLDOWN

		// Write cooldown into message
		binary.BigEndian.PutUint32( msg_raw[1:5], uint32(cooldown) )

		// Generate new prepared message
		msg_prep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msg_raw )
		if err != nil { log.Error().Err(err).Msg("Unable to generate initialization WS message") }
	
		// Send out with other messages
		ret = append(ret, msg_prep)

	}

	//==========================================================================
	// Prepare chat history message

	// Literally structured exactly the same as the chat update message
	// TODO maybe add this to its own function so I'm not maintianing the same
	// flow in two different parts? This is also in processChatUpdate

	// Only execute if we *have* a chat history
	if len(this.chatHistory) > 0 {

		// Generate JSON from stored chats
		chats_json, err := json.Marshal(this.chatHistory)
		if err != nil { log.Error().Err(err).Msg("Unable to marshal chats") }

		// Create final byte array to send out
		// Set message type and insert payload
		msg_raw := append( []byte{MSG_S_CHAT}, chats_json... )

		// Prepare message
		msg_prep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msg_raw )
		if err != nil { log.Error().Err(err).Msg("Unable to prepare chat WS message") }

		// Add to init messages
		ret = append(ret, msg_prep)

	}

	//==========================================================================
	// All init messages are prepared

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
		// Chat message

		case MSG_C_CHAT:

			//------------------------------------------------------------------
			// Pre-processing

			// Extract message language code
			lang := string(msg[1:3])

			// Extract payload of UTF8-encoded bytes and convert to string
			str := string(msg[3:])

			//------------------------------------------------------------------
			// Rejection scenarios

			// Reject all from anon and banned users
			if c.Role == ROLE_ANON || c.Role == ROLE_BANN { return false }

			// Reject all messages of unknown language
			// TODO Uses the experimental package "golang.org/x/exp/slices"
			if slices.Index(g_cfg.Langs, lang) == -1 { return false }

			//------------------------------------------------------------------
			// Processing

			// Create chat message struct
			chat := NewChatMessage( str, lang, c.Username, c.Role )

			//------------------------------------------------------------------
			// Approval

			// Queue message to be sent to clients
			this.placedChats <- chat

			// TODO Send message to appropriate Discord webhook
			g_dwm.SendMessage(chat)

			return true

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

		// Send out board and chat changes since last send tick to all clients
		case <- this.tickerUpdate.C:
			this.processChatUpdate()
			this.processBoardUpdate()
		
		// Make backup of the board (send out updates first)
		case <- this.tickerBackup.C:
			this.processBoardUpdate()
			this.processBoardBackup()

		//======================================================================
		// Process registration-related requests
		
		case c := <- this.reg:
			this.register(c)
		case c := <- this.dereg:
			this.deregister(c)
		
		//======================================================================
		// Process chat messages

		case msg := <- this.placedChats:

			//------------------------------------------------------------------
			// Manage chat history queue

			// Determine how many messages we're going to leave behind
			// If the chat history is full, only trim off the one oldest msg
			// If it's over capacity somehow, trim off more than that
			// Do nothing if it's not full -- pass 0 index to slice later
			deadmsgct := (int)(math.Max(0, (float64)(len(this.chatHistory) - g_cfg.Chat.History + 1)))

			// Re-create the history queue
			// Start with oldest messages, append new message to the end
			// If the chat history is full or overfull,
			// leave behind oldest chat messages
			this.chatHistory = append(this.chatHistory[deadmsgct:], msg)

			//------------------------------------------------------------------
			// Append to messages we need to send out

			this.chatsToSend = append(this.chatsToSend, msg)
		
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
// Update clients with new chat messages

func (this *WebSocketHub) processChatUpdate () {

	//==========================================================================
	// Initialization

	// Don't send anything if no chats sent
	if len(this.chatsToSend) == 0 { return }

	//==========================================================================
	// Processing

	// Generate JSON from stored chats
	chats_json, err := json.Marshal(this.chatsToSend)
	if err != nil { log.Error().Err(err).Msg("Unable to marshal chats") }

	// Create final byte array to send out
	// Set message type and insert payload
	msg_raw := append( []byte{MSG_S_CHAT}, chats_json... )

	// Prepare message
	msg_prep, err := websocket.NewPreparedMessage( websocket.BinaryMessage, msg_raw )
	if err != nil { log.Error().Err(err).Msg("Unable to prepare chat WS message") }

	// Send to all clients
	for c, _ := range this.clients {
		c.SendMessage(msg_prep)
	}

	//==========================================================================
	// Cleanup

	// Clear queue
	this.chatsToSend = make([]*ChatMessage, 0)

}

////////////////////////////////////////////////////////////////////////////////
// Update clients with board changes

func (this *WebSocketHub) processBoardUpdate () {

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

func (this *WebSocketHub) processBoardBackup () {

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

