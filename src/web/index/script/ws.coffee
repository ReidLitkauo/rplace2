################################################################################
# Globals

# The websocket
ws = null

################################################################################
# Helpful functions

#///////////////////////////////////////////////////////////////////////////////
# Pass a DataView into a MSGTYPE_HBOARD* message, and this function will
# render that message onto the board.

ws_paintBoard = (wsdv) ->

	# Overwrite our in-memory board state
	g_board = wsdv.buffer.slice 1, wsdv.buffer.length

	# Grab canvas context and image data
	cx = $('canvas')[0].getContext '2d'
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
	cx = $('canvas')[0].getContext '2d'
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

	ws = new WebSocket wsurl

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Handle errors and closure

	ws.onerror = ws.onclose = (e) ->
		status_set STATUS_DCONN
	
	#///////////////////////////////////////////////////////////////////////////
	# Handle messages

	ws.onmessage = ({data}) ->

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
				# Board initialization: Unauthenticated user

				when MSG_S_BOARDANON

					# Tell user to link account to proceed
					status_set STATUS_LINKACCT
				
				#---------------------------------------------------------------
				# Board initialization: Standard authenticated user

				when MSG_S_BOARDAUTH

					# Show appropriate buttons
					$('.panel.button.chat, .panel.button.settings, .panel.button.bot').removeClass 'hidden'

					# If we're not rate-limited, allow for pixel placement
					if status_get() != STATUS_COOLDOWN then status_set STATUS_PLACETILE

				#---------------------------------------------------------------
				# Board initialization: Admin user

				when MSG_S_BOARDADMN

					# Remove rate limiting
					RATELIMIT_SEC = 0

					# Show appropriate buttons
					$('.panel.button.chat, .panel.button.settings, .panel.button.admin').removeClass 'hidden'

				#---------------------------------------------------------------
				# Board initialization: Banned user

				when MSG_S_BOARDBANN
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

