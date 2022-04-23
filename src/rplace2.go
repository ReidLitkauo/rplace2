package main

import (
	"net/http"
	"math/rand"
	"time"
	"os"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

////////////////////////////////////////////////////////////////////////////////
func main () {

	//==========================================================================
	// Misc Initialization

	// Overwrite the default randomizer seed
	rand.Seed((int64)(time.Now().Unix()))

	// Properly set up logging
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	zerolog.SetGlobalLevel(zerolog.TraceLevel)
	log.Logger = log.With().Caller().Logger().Output(zerolog.ConsoleWriter{Out: os.Stdout})
	log.Info().Msg("Logging properly set up")

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

	http.HandleFunc("/endpoint/reddit-redirect", func(w http.ResponseWriter, r *http.Request) {
		EndpointRedditRedirect(w, r, g_db)
	})

	//==========================================================================
	// Static stuff

	http.Handle("/", http.FileServer(http.Dir(WEB_DIRECTORY)))

	//==========================================================================
	// Generic stuff

	err := http.ListenAndServe(":8090", nil)
	if err != nil { log.Error().Err(err).Msg("HTTP LISTEN/SERVE") }

}