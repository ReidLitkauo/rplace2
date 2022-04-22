package main

import (
	"net/http"
	"log"
	"math/rand"
	"time"
)

////////////////////////////////////////////////////////////////////////////////
func main () {

	// Overwrite the default randomizer seed
	rand.Seed((int64)(time.Now().Unix()))

	//==========================================================================
	// Websocket stuff

	g_wsh = NewWebSocketHub()

	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		NewWebSocketClient(g_wsh, w, r)
	})

	//==========================================================================
	// Database stuff

	g_db = StartDatabase()

	//==========================================================================
	// Endpoint stuff

	http.HandleFunc("/endpoint/link-reddit-account", func(w http.ResponseWriter, r *http.Request) {
		EndpointLinkRedditAccount(w, r, g_db)
	})

	//==========================================================================
	// Static stuff

	http.Handle("/", http.FileServer(http.Dir(WEB_DIRECTORY)))

	//==========================================================================
	// Generic stuff

	log.Fatal(http.ListenAndServe(":8090", nil))

}