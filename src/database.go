package main

import (
	_ "github.com/mattn/go-sqlite3"
	"database/sql"
	"log"
)

func StartDatabase () (*sql.DB) {

	db, err := sql.Open( "sqlite3", "./database.sqlite" )

	if err != nil {
		// TODO
	}

	err = db.Ping()

	if err != nil {
		log.Println(err)
	}

	return db

}