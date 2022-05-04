################################################################################
# Globals

# The websocket
l_ws = null

################################################################################
# Helpful functions

#///////////////////////////////////////////////////////////////////////////////
# Pass a DataView into a MSGTYPE_HBOARD* message, and this function will
# render that message onto the board.

ws_paintBoard = (wsdv) ->

	# Overwrite our in-memory board state
	g_board = new Uint8ClampedArray wsdv.buffer.slice 1, wsdv.buffer.length

	# Grab canvas context and image data
	cx = $('canvas.place')[0].getContext '2d'
	id = cx.getImageData 0, 0, BOARD_WIDTH, BOARD_HEIGHT

	# Process each color code passed to us
	for i in [0 ... BOARD_WIDTH * BOARD_HEIGHT]
		cc = wsdv.getUint8 i + 1
		for j in [0...4] then id.data[(i*4)+j] = PALETTE[cc][j]
	
	# Put image data
	cx.putImageData id, 0, 0

#///////////////////////////////////////////////////////////////////////////////
# Pass a DataView into a MSG_S_UPDATE message, and this function will
# render the update to the board.

ws_updateBoard = (wsdv) ->

	# Grab canvas context and image data
	cx = $('canvas.place')[0].getContext '2d'
	id = cx.getImageData 0, 0, BOARD_WIDTH, BOARD_HEIGHT

	# Process each color code passed to us
	for i in [1 ... wsdv.byteLength ] by 4

		# Grab packed pixel
		pack = wsdv.getUint32 i

		# Unpack pixel
		x = Math.floor (pack >> 8) % BOARD_WIDTH
		y = Math.floor (pack >> 8) / BOARD_WIDTH
		c = Math.floor (pack >> 0) & 0xFF

		# Update in-memory board
		g_board[ x + y * BOARD_WIDTH ] = c

		# Update canvas
		id.data.set PALETTE[c], 4 * (x + (y * BOARD_WIDTH))

	# Put image data
	cx.putImageData id, 0, 0

################################################################################
# Message sending functions

#===============================================================================
# Send a "place pixel" message

ws_send_putPixel = (x, y, c) ->

		#-----------------------------------------------------------------------
		# Initialization

		# Message variables
		ab = new ArrayBuffer 5
		dv = new DataView ab

		#-----------------------------------------------------------------------
		# Header

		# Message type
		dv.setUint8 0, MSG_C_PLACE

		#-----------------------------------------------------------------------
		# Payload

		# Create a packed pixel with color and position
		pixel = ((x + (y * BOARD_WIDTH)) << 8) | c

		# Plop the packed pixel in place
		dv.setUint32 1, pixel

		#-----------------------------------------------------------------------
		# Send

		l_ws.send dv

#===============================================================================
# Send a "place image" message
# ADMN use only, server rejects these messages if sent by other roles

ws_send_putImage = (x, y, w, h, ccs) ->

	#-----------------------------------------------------------------------
	# Initialization

	# Message variables
	ab = new ArrayBuffer 9 + (w * h)
	dv = new DataView ab
	ua = new Uint8Array ab

	#-----------------------------------------------------------------------
	# Header

	# Message type
	dv.setUint8 0, MSG_C_IMAGE

	# Set x/y/w/h
	dv.setUint16 1, x
	dv.setUint16 3, y
	dv.setUint16 5, w
	dv.setUint16 7, h

	#-----------------------------------------------------------------------
	# Payload

	ua.set ccs, 9

	#-----------------------------------------------------------------------
	# Send

	l_ws.send dv

#===============================================================================
# Send a chat message

ws_send_chat = (msg) ->

	console.log new TextEncoder().encode msg

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
	if $.cookie('session') then wsurl += "?session=" + $.cookie('session')

	#///////////////////////////////////////////////////////////////////////////
	# Establish Websocket connection

	l_ws = new WebSocket wsurl

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Handle errors and closure

	l_ws.onerror = l_ws.onclose = (e) ->
		status_set STATUS_DCONN
	
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

				when MSG_S_USERINFO

					console.log d

				#---------------------------------------------------------------
				# Board initialization: Unauthenticated user

				when MSG_S_BOARDANON

					# Tell user to link account to proceed
					status_set STATUS_LINKACCT
				
				#---------------------------------------------------------------
				# Board initialization: Standard authenticated user

				when MSG_S_BOARDAUTH

					# Set role
					g_role = AUTH

					# Show appropriate buttons
					$('.panel.button.chat, .panel.button.settings, .panel.button.bot').removeClass '-hidden'

					# If we're not rate-limited, allow for pixel placement
					if status_get() != STATUS_COOLDOWN then status_set STATUS_PLACETILE

				#---------------------------------------------------------------
				# Board initialization: Admin user

				when MSG_S_BOARDADMN

					# Set role
					g_role = ADMN

					# Remove rate limiting
					RATELIMIT_SEC = 0

					# Show appropriate buttons
					$('.panel.button.chat, .panel.button.settings, .panel.button.bot, .panel.button.admin').removeClass '-hidden'

					# Set status
					status_set STATUS_PLACETILE

				#---------------------------------------------------------------
				# Board initialization: Banned user

				when MSG_S_BOARDBANN

					# Set role
					g_role = BANN

					# Tell the user they suk
					status_set STATUS_BANNED
				
				#---------------------------------------------------------------
				# Board update

				when MSG_S_UPDATE
					ws_updateBoard d
				
				#---------------------------------------------------------------
				# Cooldown message

				when MSG_S_COOLDOWN
					status_set STATUS_COOLDOWN, d.getUint32 1
			
			#-------------------------------------------------------------------
			# Board initialization: Any user

			# Multiple message types tell us to paint the board
			# Since you can't meet two cases in a single switch ...
			# Process board drawing here.
			if msgtype is MSG_S_BOARDADMN || msgtype is MSG_S_BOARDANON || msgtype is MSG_S_BOARDAUTH || msgtype is MSG_S_BOARDBANN
				ws_paintBoard d

