package main

import (
	"github.com/kkyr/fig"
	"github.com/rs/zerolog/log"
)

////////////////////////////////////////////////////////////////////////////////
// Struct definition

type Config struct {

	Reddit_creds struct {
		Clientid string `fig:"clientid" validate:"required"`
		Secret   string `fig:"secret"   validate:"required"`
		Redirect string `fig:"redirect" validate:"required"`
	}

	Serve_from   string `fig:"serve_from" default:"web"`

	Serve_port   int    `fig:"serve_port" default:80`

	Serve_origin string `fig:"serve_origin" validate:"required"`

	Board struct {
		Width  uint16 `fig:"width"  default:2000`
		Height uint16 `fig:"height" default:2000`
		Colors byte   `fig:"colors" default:32`
	}

	Timers struct {
		Update_ms int `fig:"update_ms" default:250`
		Backup_ms int `fig:"backup_ms" default:300000`
	}

	Account_requirements struct {
		Age_years  int `fig:"age_years"  default:0`
		Age_months int `fig:"age_months" default:0`
		Age_days   int `fig:"age_days"   default:7`
		Min_karma  int `fig:"min_karma"  default:20`
	}

	Nonce_max_age_hours int `fig:"nonce_max_age_hours" default:24`

	Pixel_rate_sec int64 `fig:pixel_rate_sec default:10`

}

////////////////////////////////////////////////////////////////////////////////
// Public methods

func NewConfig () *Config {

	// Establish return value
	var cfg Config

	// Load in configuration, panic on failure
	err := fig.Load(&cfg)
	if err != nil { log.Panic().Msg("Could not load configuration") }

	// Success
	return &cfg

}
