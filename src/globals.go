package main

import (
	"database/sql"
)

const (

	BOARD_WIDTH  = 2000
	BOARD_HEIGHT = 2000

	TIMER_UPDATE_MS =  250 * 1
	TIMER_BACKUP_MS = 1000 * 60 * 5

	MSGTYPE_HBOARD = 0x10
	MSGTYPE_HUPDATE = 0x11

	MSGTYPE_CPLACE = 0x20

	WEB_DIRECTORY = "web"

	MAX_NONCE_AGE_DAYS = 1

)

// The main manager for all websocket connections.
var g_wsh *WebSocketHub

// The database connection
var g_db *sql.DB