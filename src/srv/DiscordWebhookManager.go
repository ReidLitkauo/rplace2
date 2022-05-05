//##############################################################################
// /src/srv/DiscordWebhookManager.go
// Manages sending messages to all Discord webhooks

package main

import (
	"github.com/rs/zerolog/log"
	"net/http"
	"encoding/json"
	"golang.org/x/exp/slices"
	"bytes"
)

//##############################################################################
// Struct definition

type DiscordWebhookManager struct {

	// Channel of messages to send out
	msgs chan *ChatMessage

}

//##############################################################################
// Public methods

////////////////////////////////////////////////////////////////////////////////
// Constructor

func NewDiscordWebhookManager () *DiscordWebhookManager {

	// Set up new manager
	ret := &DiscordWebhookManager {
		msgs: make(chan *ChatMessage),
	}

	// Separate goroutine to send POST requests
	go ret.processMessages()

	return ret

}

////////////////////////////////////////////////////////////////////////////////
// Submit a message to be sent to the Discord server

func (this *DiscordWebhookManager) SendMessage (msg *ChatMessage) {

	// Really just a wrapper function to add to the queue
	// Might change this later, which is why the wrapper is here!
	this.msgs <- msg

}

//##############################################################################
// Private functions

////////////////////////////////////////////////////////////////////////////////
// GOROUTINE This function turns each message into a POST request
// TODO maybe send multiple messages at once to the webhook?
// Instead of sending one POST request per message?
// So we don't overload Discord and get rate limited?
// Can we even do that?

// Good ol' for-select loop
func (this *DiscordWebhookManager) processMessages () { for { select {

	// cmsg for Chat MesSaGe
	case cmsg := <- this.msgs:

		//======================================================================
		// Initialization

		// Where are we sending the message to?

		// Get index of the message's language
		// Continue if we don't recognize the language
		lang_i := slices.Index(g_cfg.Langs, cmsg.Lang)
		if lang_i == -1 { continue }

		// Get url we should be sending this message to
		// Continue if the url is empty
		url := g_cfg.Discord_hooks[lang_i]
		if url == "" { continue }

		//======================================================================
		// Prepare message for sending

		// Special struct for Discord messages
		type discordMessage struct {
			Content  string `json:"content"`
			Username string `json:"username"`
		}

		// Make a new Discord MesSaGe
		dmsg := discordMessage{ cmsg.Msg, cmsg.Username }

		// Marshal into JSON
		msg_json, err := json.Marshal(dmsg)
		if err != nil {
			log.Error().Err(err).Msgf("Could not marshal message: Username %s Message %s", dmsg.Username, dmsg.Content)
			continue
		}

		//======================================================================
		// Send via POST request

		// Already have the URL variable
		// Already have the JSON

		// Make the request
		resp, err := http.Post(url, "application/json", bytes.NewBuffer(msg_json))

		// A fancier app would read the response, determine if we're being
		// rate limited, and wait the appropriate amount of time if so.
		// I might do that later, but for now...
		// I'm just going to log any non-2xx responses.
		// TODO catch rate limiting, make this better
		if resp.StatusCode > 299 {
			log.Error().Err(err).Msgf("Discord webhook responded with: %s", resp.Status)
		}

		// Done handling the response
		resp.Body.Close()

} } }

