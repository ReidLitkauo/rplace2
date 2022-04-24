package main

import (
	_ "github.com/mattn/go-sqlite3"
	"database/sql"
	"strconv"
	"net/http"
	"math/rand"
	"github.com/rs/zerolog/log"
	"github.com/asmcos/requests"
	"encoding/json"
	"time"
)

////////////////////////////////////////////////////////////////////////////////
// Endpoint functions

// List of validate options:
// servererror
// redditerror
// userdenied
// belowthreshold
// success

//==============================================================================
// Redirect to Reddit to start linking process
// https://github.com/reddit-archive/reddit/wiki/OAuth2

func EndpointLinkRedditAccount (w http.ResponseWriter, r *http.Request, db *sql.DB) {

	// Generate a nonce
	noncei := rand.Uint32()
	nonces := strconv.FormatUint(uint64(noncei), 16)

	// Insert nonce into database
	_, err := db.Exec("INSERT INTO nonces (nonce) VALUES (?)", noncei)
	if err != nil {
		log.Error().Err(err).Msgf("Couldn't insert nonce")
		http.Redirect(w, r, "/?validate=servererror", 303)
	}

	// The URL we're redirecting to
	url := "https://www.reddit.com/api/v1/authorize?"
	url += "&client_id="     + CRED_REDDIT_CLIENTID
	url += "&response_type=" + "code"
	url += "&state="         + nonces
	url += "&redirect_uri="  + CRED_REDDIT_REDIRECT
	url += "&duration="      + "temporary"
	url += "&scope="         + "identity"

	// Perform redirect
	http.Redirect(w, r, url, 303)

}

//==============================================================================
// Receive redirect from Reddit to complete linking process
// https://github.com/reddit-archive/reddit/wiki/OAuth2

func EndpointRedditRedirect (w http.ResponseWriter, r *http.Request, db *sql.DB) {
	// TODO pass different query strings in redirect to show error popups to user

	// Parse query string
	q := r.URL.Query()

	//--------------------------------------------------------------------------
	// Grab and check the error

	switch q.Get("error") {

		// Do nothing if no error, continue execution
		case "":

		case "unsupported_response_type": fallthrough
		case "invalid_scope": fallthrough
		case "invalid_request":
			log.Error().Msgf("Received unexpected error from Reddit redirect: %s", q.Get("error"))
			fallthrough

		// Redirect back to the main website
		// TODO be better
		case "access_denied":
			http.Redirect(w, r, "/?validate=userdenied", 303)
			return

	}

	//--------------------------------------------------------------------------
	// Grab and check the code

	reddit_code := q.Get("code")
	if reddit_code == "" {
		log.Error().Msg("Received no code from Reddit!")
		http.Redirect(w, r, "/?validate=redditerror", 303)
		return
	}

	//--------------------------------------------------------------------------
	// Check the state

	// Delete old nonces
	_, err := db.Exec("DELETE FROM nonces WHERE ts_create <= DATE('now', '-? hour')", g_cfg.Nonce_max_age_hours)
	if err != nil { log.Error().Err(err).Msg("") }

	// Grab the nonce
	nonce, err := strconv.ParseUint( q.Get("state"), 16, 32 )

	// Extract nonce
	var nonceres int
	noncerow := db.QueryRow("SELECT nonce FROM nonces WHERE nonce IS ?", nonce)
	err = noncerow.Scan(&nonceres)

	// If there's no match
	if err == sql.ErrNoRows {
		log.Warn().Msgf("Failed to act upon unknown nonce: %s", nonce)
		http.Redirect(w, r, "/?validate=servererror", 303)
		return
	}

	// If we found another error while processing the match
	if err != nil {
		log.Error().Err(err).Msg("")
		http.Redirect(w, r, "/?validate=servererror", 303)
		return
	}

	//--------------------------------------------------------------------------
	// Grab an access token

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Big long function call to place the request

	resp, err := requests.Post(
		
		// Reddit API's URL
		"https://www.reddit.com/api/v1/access_token",

		// POST data
		requests.Datas{
			"grant_type":   "authorization_code",
			"code":         reddit_code,
			"redirect_uri": CRED_REDDIT_REDIRECT,
		},

		// Pass authorization credentials
		requests.Auth{ CRED_REDDIT_CLIENTID, CRED_REDDIT_SECRET } )
	
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Run through possible error scenarios

	if resp.R.StatusCode == 401 {
		log.Error().Msg("Invalid authorization headers sent to Reddit")
		http.Redirect(w, r, "/?validate=servererror", 303)
		return
	}

	if resp.R.StatusCode != 200 {
		log.Error().Msgf("Unrecognized status code received from Reddit during OAuth flow: %d", resp.R.StatusCode)
		http.Redirect(w, r, "/?validate=redditerror", 303)
		return
	}

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Parse JSON response

	var respjson map[string]interface{}

	err = json.Unmarshal([]byte(resp.Text()), &respjson)

	if err != nil {
		log.Error().Msgf("Unable to parse JSON response from Reddit during OAuth flow: %s", resp.Text())
		http.Redirect(w, r, "/?validate=redditerror", 303)
		return
	}

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Run through more error scenarios

	reddit_err, reddit_err_exists := respjson["error"].(string)

	if reddit_err_exists && reddit_err == "unsupported_grant_type" {
		log.Error().Msg("Malformed request sent to Reddit")
		http.Redirect(w, r, "/?validate=servererror", 303)
		return
	}

	if reddit_err_exists && reddit_err == "invalid_grant" {
		log.Warn().Msgf("Reused/expired code: %s", reddit_code)
		http.Redirect(w, r, "/?validate=servererror", 303)
		return
	}

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Actually grab the freaking code

	reddit_token, reddit_token_exists := respjson["access_token"].(string)

	if !reddit_token_exists {
		log.Error().Msgf("No Reddit access token in an otherwise well-formed response")
		http.Redirect(w, r, "/?validate=redditerror", 303)
		return
	}

	//--------------------------------------------------------------------------
	// Get their Reddit username

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// The big get call

	meresp, err := requests.Get(

		// Different URL
		"https://oauth.reddit.com/api/v1/me",

		// Pass the OAuth bearer token
		requests.Header{ "Authorization": "bearer " + reddit_token } )
	
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Error handling

	if meresp.R.StatusCode != 200 {
		log.Error().Msgf("Unrecognized status code received from Reddit during /me call: %d", meresp.R.StatusCode)
		http.Redirect(w, r, "/?validate=redditerror", 303)
		return
	}

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Parse JSON response

	var mejson map[string]interface{}

	err = json.Unmarshal([]byte(meresp.Text()), &mejson)

	if err != nil {
		log.Error().Msgf("Unable to parse JSON response from Reddit during OAuth flow: %s", meresp.Text())
		http.Redirect(w, r, "/?validate=redditerror", 303)
		return
	}

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// More error handling

	me_err, me_err_exists := mejson["error"].(string)

	if me_err_exists {
		log.Error().Msgf("Received error from Reddit during call to /me: %s", me_err)
		http.Redirect(w, r, "/?validate=redditerror", 303)
		return
	}

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// FINALLY get the freaking username

	me, me_exists := mejson["name"]

	if !me_exists {
		log.Error().Msgf("Didn't receive a username from Reddit")
		http.Redirect(w, r, "/?validate=redditerror", 303)
		return
	}

	//--------------------------------------------------------------------------
	// Check account eligibility requirements

	// Grab created/karma interfaces from json
	created_iface, created_exists := mejson["created_utc"]
	karma_iface, karma_exists := mejson["total_karma"]

	// Validate existence
	if !created_exists || !karma_exists {
		log.Error().Msgf("Didn't receive both created and karma from Reddit")
		http.Redirect(w, r, "/?validate=redditerror", 303)
		return
	}

	// Convert to primitives
	created := int64(created_iface.(float64))
	karma := int64(karma_iface.(float64))

	// Perform comparison
	// TODO put in config file
	if (created > time.Now().AddDate(-10, 0, 0).Unix()) || (karma < 900) {
		http.Redirect(w, r, "/?validate=belowthreshold", 303)
	}

	//--------------------------------------------------------------------------
	// Establish a session

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Generate a random string

	session := ""

	for _ = range "01234567" {
		session += strconv.FormatUint(uint64(rand.Uint32()), 16)
	}

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Store association between session and user

	_, err = db.Exec("INSERT INTO sessions (session, username) VALUES (?, ?)", session, me)

	if err != nil {
		log.Error().Err(err).Msgf("Error inserting session into database")
		http.Redirect(w, r, "/?validate=servererror", 303)
		return
	}

	//--------------------------------------------------------------------------
	// SESSION SET - RETURN TO USER

	// Set cookie
	w.Header().Set("Set-Cookie", "session=" + session + "; Path=/; Max-Age=3155695200")

	// Return the user to the application
	http.Redirect(w, r, "/?validate=success", 303)

}