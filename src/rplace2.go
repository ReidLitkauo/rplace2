package main

import (
	"net/http"
	"log"
)

////////////////////////////////////////////////////////////////////////////////
// Globals

// The main manager for all websocket connections.
var g_wsh *WebSocketHub

const (

	BOARD_WIDTH  = 2000
	BOARD_HEIGHT = 2000

	TIMER_UPDATE_MS =  250 * 1
	TIMER_BACKUP_MS = 1000 * 60 * 5

	MSGTYPE_HBOARD = 0x10
	MSGTYPE_HUPDATE = 0x11

	WEB_DIRECTORY = "web"

)

// Pixel packing/unpacking helper functions
// Packed pixels are the size of a uint32 and are formatted like this:
// index (x + (y * WIDTH)) (24 bits) | color-code (8 bits)
// 2-version converts x and y into a single index
// 3-version separates them out

func PackPixel2 (i uint32, c byte) (uint32) {
	return ((i & 0xFFFFFF) << 8) | (((uint32)(c) & 0xFF) << 0)
}

func PackPixel3 (x uint32, y uint32, c byte) (uint32) {
	return PackPixel2( x + (y * BOARD_WIDTH), c )
}

func UnpackPixel2 (p uint32) (uint32, byte) {
	return ((p >> 8) & 0xFFFFFF), (byte)((p >> 0) & 0xFF)
}

func UnpackPixel3 (p uint32) (uint32, uint32, byte) {
	i, c := UnpackPixel2(p)
	return i % BOARD_WIDTH, i / BOARD_WIDTH, c
}

////////////////////////////////////////////////////////////////////////////////
func main () {

	//==========================================================================
	// Websocket stuff

	g_wsh = NewWebSocketHub()

	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		NewWebSocketClient(g_wsh, w, r)
	})

	//==========================================================================
	// Endpoint stuff

	//==========================================================================
	// Static stuff

	http.Handle("/", http.FileServer(http.Dir(WEB_DIRECTORY)))

	//==========================================================================
	// Generic stuff

	log.Fatal(http.ListenAndServe(":8090", nil))

}