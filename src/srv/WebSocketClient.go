//##############################################################################
// /src/WebSocketClient.go
// Handles a single client connection.

package main

import (
	"github.com/rs/zerolog/log"
	"net/http"
	//"encoding/binary"
	"github.com/gorilla/websocket"
	"database/sql"
)

//##############################################################################
// Struct definition

type WebSocketClient struct {

	////////////////////////////////////////////////////////////////////////////
	// Public fields

	// This client's username, if any
	Username string

	// This user's role
	Role int

	////////////////////////////////////////////////////////////////////////////
	// Private fields

	// The hub this client is connected to
	wsh *WebSocketHub

	// The websocket connection
	ws *websocket.Conn

	// Channel of messages to send to this client
	send chan *websocket.PreparedMessage

	// The session cookie used to authenticate this client, if any
	session string

}

//##############################################################################
// Public methods

////////////////////////////////////////////////////////////////////////////////
// Constructor

func NewWebSocketClient (wsh *WebSocketHub, db *sql.DB, w http.ResponseWriter, r *http.Request) *WebSocketClient {

	//==========================================================================
	// Perform authentication

	// Variable declaration
	var session string
	var username string
	role := (int)(ROLE_ANON) // Default

	//--------------------------------------------------------------------------
	// Get session from query

	// Retrieve session cookie
	session = r.URL.Query().Get("session")

	// We actually do have a session
	if session != "" {

		//----------------------------------------------------------------------
		// Get username from session

		userrow := db.QueryRow("SELECT username FROM sessions WHERE session IS ?", session)
		err := userrow.Scan(&username)

		// Catch errors
		switch err {

			// Do nothing
			case nil:

			// Couldn't find session. Either we got a weird session value,
			// or someone's using an expired session.
			// In either case, behave as if user is logged out.
			case sql.ErrNoRows:
				session = ""
			
			// Something else happened
			default:
				log.Error().Err(err).Msg("")
				return nil

		}

		// Found a username
		if username != "" {

			//----------------------------------------------------------------------
			// Get role from username

			rolerow := db.QueryRow("SELECT role FROM users WHERE username IS ?", username)
			err = rolerow.Scan(&role)

			// Not finding a role after finding a username is bad news bears
			// That means something weeeeeird happened
			if err != nil {
				log.Error().Err(err).Msgf("Couldn't find user %s in users table", username)
				return nil
			}

		}

	}

	//==========================================================================
	// Upgrade connection

	// Specifications for the websocket upgrader
	// TODO move these constants to a better spot
	// TODO be smarter about what I accept from reading
	upgrader := websocket.Upgrader {
		ReadBufferSize:  5000000,
		WriteBufferSize: 5000000,
	}

	// Only allow the specified origin, to prevent attacks
	// NOTE also fixes some weird bug when I was setting up NGINX as a reverse proxy
	upgrader.CheckOrigin = func (r *http.Request) bool {
		return r.Header["Origin"][0] == g_cfg.Serve.Origin
	}

	// Perform the upgrade
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil { log.Warn().Err(err).Msg("Unable to upgrade WS connection") }

	// Set ws connection parameters
	// TODO constants
	ws.SetReadLimit(64)

	//==========================================================================
	// Set up and return object

	// Create the new WSClient object
	wsc := &WebSocketClient{
		Username: username,
		Role:     role,
		wsh:      wsh,
		ws:       ws,
		send:     make(chan *websocket.PreparedMessage, 256),
		session:  session,
	}	

	// Request registration to the hub
	wsh.RequestRegistration(wsc)

	// Run send/recv goroutines
	go wsc.handleSend()
	if username != "" { go wsc.handleRecv() }

	// Send initialization message
	for _, msg := range(wsh.GetInitializationMessages(username, role)) {
		wsc.SendMessage(msg)
	}

	// Success
	return wsc

}

////////////////////////////////////////////////////////////////////////////////
// Message handling

// Send a message to this client
func (this *WebSocketClient) SendMessage (m *websocket.PreparedMessage) {
	this.send <- m
}

//##############################################################################
// Private methods

////////////////////////////////////////////////////////////////////////////////
// GOROUTINE Send out all queued messages

func (this *WebSocketClient) handleSend () {

	// Cleanup
	defer func() {
		this.wsh.RequestDeregistration(this)
		this.ws.Close()
	}()

	// Main handling loop
	// Pretty dumb, just write all messages queued
	for { select {

		case msg := <- this.send:

			this.ws.WritePreparedMessage(msg)

	} }

}

////////////////////////////////////////////////////////////////////////////////
// GOROUTINE Receive messages from client

func (this *WebSocketClient) handleRecv () {

	// Cleanup
	defer func() {
		this.wsh.RequestDeregistration(this)
		this.ws.Close()
	}()

	// Start main handling loop
	for {

		// Wait for the next message, breaking upon closure
		_, msg, err := this.ws.ReadMessage()
		if err != nil { break }

		// See if the message will be accepted
		this.wsh.RequestAcceptMessage(this, msg)

	}

}