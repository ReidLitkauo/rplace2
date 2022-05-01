################################################################################
# Websocket Handling

# Pass a DataView into a MSGTYPE_HBOARD* message, and this function will
# render that message onto the board.
render_paintBoard = (wsdv) ->

	# Grab canvas context and image data
	cx = $('canvas')[0].getContext '2d'
	id = cx.getImageData 0, 0, BOARD_WIDTH, BOARD_HEIGHT

	# Process each color code passed to us
	for i in [0 ... BOARD_WIDTH * BOARD_HEIGHT]
		cc = wsdv.getUint8 i + 1
		for j in [0...4] then id.data[(i*4)+j] = PALETTE[cc][j]
	
	# Put image data
	cx.putImageData id, 0, 0

# Pass a DataView into a MSG_S_UPDATE message, and this function will
# render the update to the board.
render_updateBoard = (wsdv) ->

	# Grab canvas context and image data
	cx = $('canvas')[0].getContext '2d'
	id = cx.getImageData 0, 0, BOARD_WIDTH, BOARD_HEIGHT

	# Process each color code passed to us
	for i in [1 ... wsdv.byteLength ] by 4
		pack = wsdv.getUint32 i
		x = Math.floor (pack >> 8) % BOARD_WIDTH
		y = Math.floor (pack >> 8) / BOARD_WIDTH
		c = Math.floor (pack >> 0) & 0xFF
		id.data.set PALETTE[c], 4 * (x + (y * BOARD_WIDTH))

	# Put image data
	cx.putImageData id, 0, 0

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Initialization and message processing

$ ->

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Initialization

	# Build out websocket URL
	wsprotocol = if document.location.protocol == 'https:' then 'wss:' else 'ws:'
	wsurl = wsprotocol + "//" + document.location.host + "/ws"
	if document.cookie then wsurl += "?session=" + $.cookie('session')

	# Establish Websocket connection
	window.ws = new WebSocket wsurl

	# Handle errors and closure
	window.ws.onerror = window.ws.onclose = (e) ->
		ui_setStatus STATUS_DCONN
	
	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Handle messages

	window.ws.onmessage = ({data}) ->
		data.arrayBuffer().then (raw) ->
			d = new DataView(raw)
			msgtype = d.getUint8 0

			# Process message
			switch msgtype

				#       #       #       #       #       #       #       #       
				# Unauthenticated user

				when MSG_S_BOARDANON

					# Tell user to link account to proceed
					ui_setStatus STATUS_LINKACCT
				
				#       #       #       #       #       #       #       #       
				# Standard authenticated user

				when MSG_S_BOARDAUTH

					# Show appropriate buttons
					$('.panel.button.chat, .panel.button.settings, .panel.button.bot').removeClass 'hidden'

					# If we're not rate-limited, allow for pixel placement
					if ui_getStatus() != STATUS_COOLDOWN then ui_setStatus STATUS_PLACETILE

				#       #       #       #       #       #       #       #       
				# Admin user

				when MSG_S_BOARDADMN

					# Remove rate limiting
					RATELIMIT_SEC = 0

					# Show appropriate buttons
					$('.panel.button.chat, .panel.button.settings, .panel.button.admin').removeClass 'hidden'

				#       #       #       #       #       #       #       #       
				# Banned user

				when MSG_S_BOARDBANN
					ui_setStatus STATUS_BANNED

				# Board update
				when MSG_S_UPDATE
					render_updateBoard d
				
				# Ratelimit message
				when MSG_S_COOLDOWN
					ui_setStatus STATUS_COOLDOWN, d.getUint32 1
			
			# Multiple message types tell us to paint the board
			# Since you can't meet two cases in a single switch ...
			# Process board drawing here.
			if msgtype is MSG_S_BOARDADMN || msgtype is MSG_S_BOARDANON || msgtype is MSG_S_BOARDAUTH || msgtype is MSG_S_BOARDBANN
				render_paintBoard d

