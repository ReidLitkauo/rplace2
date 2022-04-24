package main

import (
	"database/sql"
)

////////////////////////////////////////////////////////////////////////////////
// Globals

// Application configuration
var g_cfg *Config

// The main manager for all websocket connections.
var g_wsh *WebSocketHub

// The database connection
var g_db *sql.DB

////////////////////////////////////////////////////////////////////////////////
// Constants

const (

	// Hub message types
	MSGTYPE_HBOARDANON = 0x10
	MSGTYPE_HBOARDAUTH = 0x11
	MSGTYPE_HUPDATE    = 0x12
	MSGTYPE_HRATELIMIT = 0x13

	// Client message types
	MSGTYPE_CPLACE = 0x20
	MSGTYPE_CRECT  = 0x21

)

