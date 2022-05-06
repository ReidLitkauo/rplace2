################################################################################
# /web/index/script/text.coffee
# All text displayed to the user lives in this file.
# Allows for multiple languages to be used, and to switch languages instantly.
# In a larger project, this sort of stuff would be stored in a database or
# something, and would be handled server-side.
# But meh. This project is small enough for this sort of thing to not be that
# big of a deal.

export default

	############################################################################
	# Color names
	# In order of appearance on the palette

	'colors': [
		{ 'en': "Darkest Red", }
		{ 'en': "Dark Red",    }
		{ 'en': "Bright Red",  }
		{ 'en': "Orange",      }
		{ 'en': "Yellow",      }
		{ 'en': "Pale Yellow", }
		{ 'en': "Dark Green",  }
		{ 'en': "Green",       }
		{ 'en': "Light Green", }
		{ 'en': "Dark Teal",   }
		{ 'en': "Teal",        }
		{ 'en': "Light Teal",  }
		{ 'en': "Dark Blue",   }
		{ 'en': "Blue",        }
		{ 'en': "Light Blue",  }
		{ 'en': "Indigo",      }
		{ 'en': "Periwinkle",  }
		{ 'en': "Lavender",    }
		{ 'en': "Dark Purple", }
		{ 'en': "Purple",      }
		{ 'en': "Pale Purple", }
		{ 'en': "Magenta",     }
		{ 'en': "Pink",        }
		{ 'en': "Light Pink",  }
		{ 'en': "Dark Brown",  }
		{ 'en': "Brown",       }
		{ 'en': "Beige",       }
		{ 'en': "Black",       }
		{ 'en': "Dark Gray",   }
		{ 'en': "Gray",        }
		{ 'en': "Light Gray",  }
		{ 'en': "White",       }
	]

	############################################################################
	# Statuses
	# Shown to the user on the status bar at the bottom

	'status':

		#///////////////////////////////////////////////////////////////////////
		# Loading
		# Shown when page is initializing, before MSG_S_BOARD* received

		'loading':
			'en': "Loading..."
	
		#///////////////////////////////////////////////////////////////////////
		# Link Account
		# CTA shown to anons, request linking a Reddit account to use the site

		'linkacct':
			'en': "Link your Reddit account"
		
		#///////////////////////////////////////////////////////////////////////
		# Place Tile
		# Shown to authorized/admin users, pulls up the color palette
	
		'placetile':
			'en': "Place a tile"
	
		#///////////////////////////////////////////////////////////////////////
		# Connection Error
		# Shown when the websocket encounters an error

		'connerr':
			'en': "Couldn't connect!"
	
		#///////////////////////////////////////////////////////////////////////
		# Disconnection
		# Shown when the user is disconnected from the server

		'dconn':
			'en': "Disconnected"
	
		#///////////////////////////////////////////////////////////////////////
		# Banned
		# Shown to banned users, prohibits all tile placement

		'banned':
			'en': "Your account is banned"

		#///////////////////////////////////////////////////////////////////////
		# Bot Positioning
		# Shown to users who are positioning an image for the bot
		# Should be an invitation to place the image

		'botpos':
			'en': "Place image"
	
		#///////////////////////////////////////////////////////////////////////
		# Bot Running
		# Shown when the bot is actively placing images

		'botrun':
			'en': "Placing image..."

	############################################################################
	# Account Validation Errors
	# Shown as a popup to users when they link their Reddit account

	'validate':

		#///////////////////////////////////////////////////////////////////////
		# Server Error
		# Shown to user when something funky happens on my site

		'servererror':
			'en': "This website encountered a technical error while trying to link your account. Please reach out via Discord, or try again later."

		#///////////////////////////////////////////////////////////////////////
		# Reddit Error
		# Shown to user when something funky happens on Reddit's end

		'redditerror':
			'en': "Reddit ran into a problem while trying to link your account. Please reach out via Discord, or try again later."

		#///////////////////////////////////////////////////////////////////////
		# User Banned
		# An admin has banned this user

		'userbanned':
			'en': "Your account is banned from this platform. If you feel this is in error, please reach out to an admin on our Discord server."

		#///////////////////////////////////////////////////////////////////////
		# Below Threshold
		# Account does not meet minimum age/karma requirements

		'belowthreshold':
			'en': "Your account does not meet our minimum age and karma requirements. Please use Reddit a bit more, and try again later."

		#///////////////////////////////////////////////////////////////////////
		# User Denied
		# The user did not allow the app access to their account
		# Try to make them feel better, be honest about what we do, and
		# encourage them to let us know if they have any concerns

		'userdenied':
			'en': "We only need access to your username, account age, and total karma in order to link your account &ndash; not your post/comment history or anything else. If you have concerns about our account linkage flow or what data we collect, please reach out to us via Discord."

