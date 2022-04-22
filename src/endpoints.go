package main

import (
	_ "github.com/mattn/go-sqlite3"
	"database/sql"
	"strconv"
	"net/http"
	"math/rand"
	"log"
)

func EndpointLinkRedditAccount (w http.ResponseWriter, r *http.Request, db *sql.DB) {

	// Generate a nonce
	noncei := rand.Uint32()
	nonces := strconv.FormatUint(uint64(noncei), 16)

	// TODO prepare this statement somewhere else and hold in memory for reuse
	stmt, err := db.Prepare("INSERT INTO nonces (nonce) VALUES (?)")

	if err != nil {
		// TODO
	}

	_, err = stmt.Exec(noncei)
	
	if err != nil {
		// TODO
		log.Println(err)
	}

	err = stmt.Close()

	if err != nil {
		// TODO
	}

	// The URL we're redirecting to
	url := "https://www.reddit.com/api/v1/authorize?"
	url += "&client_id="     + CRED_REDDIT_CLIENTID
	url += "&response_type=" + "code"
	url += "&state="         + nonces
	url += "&redirect_uri="  + CRED_REDDIT_REDIRECT
	url += "&duration="      + "permanent"
	url += "&scope="         + "identity"

	http.Redirect(w, r, url, 303)
}