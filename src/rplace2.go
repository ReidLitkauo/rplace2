package main

import (
	"net/http"
	"math/rand"
	"time"
	"os"
	"strconv"
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
	log.Info().Msg("Logging initialized")

	//==========================================================================
	// Configuration initialization

	g_cfg = NewConfig()
	log.Info().Msg("Configuration initialized")

	//==========================================================================
	// Websocket stuff

	g_wsh = NewWebSocketHub()
	log.Info().Msg("Websockets initialized")

	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		NewWebSocketClient(g_wsh, g_db, w, r)
	})

	//==========================================================================
	// Database stuff

	g_db = StartDatabase()
	log.Info().Msg("Database initialized")


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

	http.Handle("/", http.FileServer(http.Dir(g_cfg.Serve_from)))

	//==========================================================================
	// Generic stuff

	log.Info().Msg("Ready to listen and serve on port " + strconv.Itoa(g_cfg.Serve_port))
	err := http.ListenAndServe(":" + strconv.Itoa(g_cfg.Serve_port), nil)
	if err != nil { log.Error().Err(err).Msg("HTTP LISTEN/SERVE") }

}