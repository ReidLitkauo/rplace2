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

	// User roles

	ROLE_ANON = 0x80 // Dummy role
	ROLE_AUTH = 0x81
	ROLE_BANN = 0x82
	ROLE_ADMN = 0x83

	// Server message types

	MSG_S_USERINFO  = 0x10

	MSG_S_BOARDANON = 0x20
	MSG_S_BOARDAUTH = 0x21
	MSG_S_BOARDBANN = 0x22
	MSG_S_BOARDADMN = 0x23

	MSG_S_UPDATE    = 0x30

	MSG_S_COOLDOWN  = 0x40

	// Client message types

	MSG_C_PLACE = 0xA0
	MSG_C_IMAGE = 0xA1
	//MSG_C_RECT  = 0xA1

)

