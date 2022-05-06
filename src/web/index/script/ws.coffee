################################################################################
# /src/web/index/script/ws.coffee
# Manages this client's websocket connection, sends and parses messages

jsdom = require('jsdom')
$ = if window? then require('jquery') else require('jquery')(new jsdom.JSDOM().window)
import Cookie from 'js-cookie'

import Globals from './globals.coffee'

import * as Chat    from './chat.coffee'
import * as Palette from './palette.coffee'
import * as Status  from './status.coffee'

################################################################################
# Exported variables

################################################################################
# Private variables

# The websocket
l_ws = null

################################################################################
# Exported functions

#///////////////////////////////////////////////////////////////////////////////
# Send a "place pixel" message

export sendPixel = (x, y, c) ->

	#===========================================================================
	# Initialization

	# Message variables
	ab = new ArrayBuffer 5
	dv = new DataView ab
	ua = new Uint8Array ab

	#===========================================================================
	# Header

	# Message type
	dv.setUint8 0, Globals.MSG_C_PLACE

	#===========================================================================
	# Payload

	# Create a packed pixel with color and position
	pixel = ((x + (y * Globals.BOARD_WIDTH)) << 8) | c

	# Plop the packed pixel in place
	dv.setUint32 1, pixel

	#===========================================================================
	# Send

	l_ws?.send dv

	ua

#///////////////////////////////////////////////////////////////////////////////
# Send a "place image" message
# ADMN use only, server rejects these messages if sent by other roles

export sendImage = (x, y, w, h, ccs) ->

	#===========================================================================
	# Initialization

	# Message variables
	ab = new ArrayBuffer 9 + (w * h)
	dv = new DataView ab
	ua = new Uint8Array ab

	#===========================================================================
	# Header

	# Message type
	dv.setUint8 0, Globals.MSG_C_IMAGE

	# Set x/y/w/h
	dv.setUint16 1, x
	dv.setUint16 3, y
	dv.setUint16 5, w
	dv.setUint16 7, h

	#===========================================================================
	# Payload

	ua.set ccs, 9

	#===========================================================================
	# Send

	l_ws?.send dv

	ua

#///////////////////////////////////////////////////////////////////////////////
# Send a chat message

export sendChat = (msg) ->

	#===========================================================================
	# Initialization

	# Convert the message to a byte array
	# Gotta do this first to know how long the message ought to be
	# TextEncoder defaults to UTF8
	msg_encoded = new TextEncoder().encode msg

	# Create final message
	ab = new ArrayBuffer 3 + msg_encoded.length
	dv = new DataView ab
	ua = new Uint8Array ab

	#===========================================================================
	# Header

	# Message type
	dv.setUint8 0, Globals.MSG_C_CHAT

	# Message language
	ua.set new TextEncoder().encode('en'), 1

	#===========================================================================
	# Payload

	# Set message payload as the encoded message we made earlier
	ua.set msg_encoded, 3

	#===========================================================================
	# Send

	l_ws?.send dv

	ua

################################################################################
# Private functions

#///////////////////////////////////////////////////////////////////////////////
# Extract JSON from a message

extractJSON = (wsdv) -> 

	# Did a lot of fiddling in the JS console to get this juuuuust right
	# - Make a typed array out of the buffer behind the message
	# - Chop off the first byte and run the rest through a UTF8 decoder
	# - Parse the resulting text into a JS object
	JSON.parse new TextDecoder().decode new Uint8Array(wsdv.buffer).slice 1

#///////////////////////////////////////////////////////////////////////////////
# Receive user information

recvUser = (wsdv) ->

	#===========================================================================
	# Initialization

	# Grab encoded JSON data
	wsmsg = extractJSON wsdv

	# Set global user role
	Globals.role = wsmsg.role

	# Let's see what type of user it is
	switch wsmsg.role

		#=======================================================================
		# Anonymous user

		when Globals.ROLE_ANON

			# Tell user to link account to proceed
			Status.set Status.LINKACCT
		
		#=======================================================================
		# Banned user

		when Globals.ROLE_BANN

			# Tell user they are banned :(
			Status.set Status.BANNED

		#=======================================================================
		# Authenticated user

		when Globals.ROLE_AUTH

			# Show appropriate buttons
			$('.panel.button.chat, .panel.button.settings, .panel.button.bot').removeClass '-hidden'

			# If we're not rate-limited, allow for pixel placement
			if Status.get() isnt Status.COOLDOWN then Status.set Status.PLACETILE

		#=======================================================================
		# Admin user

		when Globals.ROLE_ADMN

			# Remove rate limiting
			RATELIMIT_SEC = 0

			# Show appropriate buttons
			$('.panel.button.chat, .panel.button.settings, .panel.button.bot, .panel.button.admin').removeClass '-hidden'

			# Set status
			Status.set Status.PLACETILE

#///////////////////////////////////////////////////////////////////////////////
# Receive the board
# Pass a DataView into a MSGTYPE_HBOARD* message, and this function will
# render that message onto the board.

recvBoard = (wsdv) ->

	# Overwrite our in-memory board state
	Globals.board = new Uint8ClampedArray wsdv.buffer.slice 1, wsdv.buffer.length

	# Grab canvas context and image data
	cx = $('canvas.place')[0].getContext '2d'
	id = cx.getImageData 0, 0, Globals.BOARD_WIDTH, Globals.BOARD_HEIGHT

	# Cache values, next computation is expensive
	w = Globals.BOARD_WIDTH
	h = Globals.BOARD_HEIGHT
	p = Palette.PALETTE

	# Process each color code passed to us
	# TODO optimize! This got very slow after I migrated to webpack
	for i in [0 ... w * h]
		cc = wsdv.getUint8 i + 1
		for j in [0...4] then id.data[(i*4)+j] = p[cc][j]
	
	# Put image data
	cx.putImageData id, 0, 0

#///////////////////////////////////////////////////////////////////////////////
# Receive a board update
# Pass a DataView into a MSG_S_UPDATE message, and this function will
# render the update to the board.

recvUpdate = (wsdv) ->

	# Grab canvas context and image data
	cx = $('canvas.place')[0].getContext '2d'
	id = cx.getImageData 0, 0, Globals.BOARD_WIDTH, Globals.BOARD_HEIGHT

	# Process each color code passed to us
	for i in [1 ... wsdv.byteLength ] by 4

		# Grab packed pixel
		pack = wsdv.getUint32 i

		# Unpack pixel
		x = Math.floor (pack >> 8) % Globals.BOARD_WIDTH
		y = Math.floor (pack >> 8) / Globals.BOARD_WIDTH
		c = Math.floor (pack >> 0) & 0xFF

		# Update in-memory board
		Globals.board[ x + y * Globals.BOARD_WIDTH ] = c

		# Update canvas
		id.data.set Palette.PALETTE[c], 4 * (x + (y * Globals.BOARD_WIDTH))

	# Put image data
	cx.putImageData id, 0, 0

#///////////////////////////////////////////////////////////////////////////////
# Receive a chat message

recvChat = (wsdv) ->

	# Extract chat info and send off to the chat manager
	Chat.displayMessages extractJSON wsdv

#///////////////////////////////////////////////////////////////////////////////
# Receive a cooldown message

recvCooldown = (wsdv) ->

	# Extract cooldown from message and show to user
	Status.set Status.COOLDOWN, wsdv.getUint32 1

################################################################################
# Initialization

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Build out websocket URL

	# Start with protocol, match to window
	wsurl = if document.location.protocol == 'https:' then 'wss:' else 'ws:'

	# Add current host, no need to hardcode this in
	# This plays nice with the server's CSRF protection
	wsurl += "//" + document.location.host + "/ws"

	# Append session cookie if we have one
	if Cookie.get('session') then wsurl += "?session=" + Cookie.get('session')

	#///////////////////////////////////////////////////////////////////////////
	# Establish Websocket connection

	l_ws = new WebSocket wsurl

	################################################################################
	# Event handling

	#///////////////////////////////////////////////////////////////////////////
	# Handle errors and closure

	l_ws.onerror = l_ws.onclose = (e) ->
		Status.set Status.DCONN
	
	#///////////////////////////////////////////////////////////////////////////
	# Handle messages

	l_ws.onmessage = ({data}) ->

		#=======================================================================
		# Initialization

		# Why does this return a promise :(
		data.arrayBuffer().then (raw) ->

			# Grab a data view of the message and find the message type
			d = new DataView(raw)
			msgtype = d.getUint8 0

			# Process message
			switch msgtype

				#---------------------------------------------------------------
				# User information message

				when Globals.MSG_S_USERINFO
					recvUser d

				#---------------------------------------------------------------
				# Board initialization

				when Globals.MSG_S_BOARD
					recvBoard d

				#---------------------------------------------------------------
				# Chat message

				when Globals.MSG_S_CHAT
					recvChat d
				
				#---------------------------------------------------------------
				# Board update

				when Globals.MSG_S_UPDATE
					recvUpdate d
				
				#---------------------------------------------------------------
				# Cooldown message

				when Globals.MSG_S_COOLDOWN
					recvCooldown d
			
