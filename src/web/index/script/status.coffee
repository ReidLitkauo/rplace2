################################################################################
# /src/web/index/script/status.coffee
# Handles displaying statuses, changing statuses, etc...

import $ from 'jquery'

import Globals from './globals.coffee'
import Text    from './text.coffee'

import * as Bot     from './bot.coffee'
import * as Palette from './palette.coffee'
import * as Pos     from './pos.coffee'

################################################################################
# Exported variables

# Various status codes and their associated keys
export LOADING   = 'loading'
export LINKACCT  = 'linkacct'
export PLACETILE = 'placetile'
export CONNERR   = 'connerr'
export DCONN     = 'dconn'
export COOLDOWN  = 'cooldown'
export BANNED    = 'banned'
export BOTPOS    = 'botpos'
export BOTRUN    = 'botrun'

################################################################################
# Private variables

# The current status
l_status = LOADING

################################################################################
# Exported functions

#///////////////////////////////////////////////////////////////////////////////
# Set status

export set = (s, timeleft = Globals.RATELIMIT_SEC) ->

	#===========================================================================
	# Common preprocessing

	# Grab reference to the status panel
	panel = $('.panel.status')

	# Set dataset attribute right away
	panel[0].dataset.mode = s

	# Save status for later
	l_status = s

	#===========================================================================
	# Special considerations

	# Do we need to widen the status bar?
	if s == LINKACCT || s == BANNED
		panel.addClass 'wide'
	else
		panel.removeClass 'wide'
	
	# Special handling for cooldown status, do nothing else
	if s == COOLDOWN
		handleCooldown()
		return s

	#===========================================================================
	# Show status to user

	# TODO support multiple languages
	panel.text Text.status[s]['en']

	# Return
	s

#///////////////////////////////////////////////////////////////////////////////
# Retrieve status

export get = -> l_status

################################################################################
# Private functions

#///////////////////////////////////////////////////////////////////////////////
# Special handling for cooldown message

handleCooldown = (cooldown = Globals.RATELIMIT_SEC) ->

	#===========================================================================
	# Initialization

	# Set up cooldown UI
	$('.panel.status').html "
			<img class='timeleft' src='/timer.svg' />
			<div class='timeleft'></div>
		"

	# Allow cooldown to be visible globally
	Globals.cooldown = cooldown

	#===========================================================================
	# Update cooldown and UI

	# Define a function to be called once a second,
	# to update the cooldown timer shown to the user
	intervalfn = () ->

		#-----------------------------------------------------------------------
		# Break scenarios

		# No point in continuing if status has changed since last update
		if get() isnt COOLDOWN
			clearTimeout interval
			return

		# Clear the interval if we don't need it anymore
		if Globals.cooldown <= 0
			Globals.cooldown = null
			clearTimeout interval
			set PLACETILE
			return
		
		#-----------------------------------------------------------------------
		# Process update

		# Determine hours/minutes/seconds left
		h = Math.floor(Globals.cooldown / 3600)
		m = Math.floor((Globals.cooldown % 3600) / 60)
		s = Math.floor(Globals.cooldown % 60)

		# Add padding zeroes if needed
		hs = (if h < 10 then "0" else "") + h
		ms = (if m < 10 then "0" else "") + m
		ss = (if s < 10 then "0" else "") + s
		
		# Display the properly-formatted time left
		$('.panel.status .timeleft').html "#{hs}:#{ms}:#{ss}"

		# Decrement our time left by one second
		Globals.cooldown--
	
	#---------------------------------------------------------------------------
	# Initialize

	# Set the interval
	interval = setInterval intervalfn, 1000

	# And run for the first time, setInterval waits a second for the first call
	intervalfn()

################################################################################
# Initialization

$ ->

	# Set initial status
	set LOADING

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Clicked on status bar: Do whatever is most appropriate

	$('.panel.status').on 'click', (e) ->
		
		switch get()

			#when LOADING

			#===================================================================
			# Link account: Start reddit account linkage webflow

			when LINKACCT
				window.open(document.location.protocol + "//" + document.location.host + "/endpoint/link-reddit-account", "_blank").focus()

			#===================================================================
			# Place tile: Show the palette

			when PLACETILE

				# Center the view on the selected pixel
				pos = Pos.val()
				Pos.set pos.xf + 0.5, pos.yf + 0.5, null

				# Show the palette
				Palette.open()

			#===================================================================
			# Bot positioning: Place the image

			when BOTPOS

				# Start the bot normally if we're a normal user
				if Globals.role is Globals.ROLE_AUTH then Bot.start()

				# Admins get access to insta-place
				if Globals.role is Globals.ROLE_ADMN then Bot.instaplace()

			#===================================================================
			# Bot running: Stop the bot

			when BOTRUN
				Bot.cancel()

