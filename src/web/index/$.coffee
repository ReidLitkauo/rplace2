################################################################################
# Constants
# Must be kept the same as the ones used by the server

BOARD_WIDTH = BOARD_HEIGHT = 2000

MSGTYPE_HBOARDANON = 0x10
MSGTYPE_HBOARDAUTH = 0x11
MSGTYPE_HUPDATE    = 0x12
MSGTYPE_HRATELIMIT = 0x13

MSGTYPE_CPLACE = 0x20

RATELIMIT_SEC = 10

STATUS_LOADING   = 'loading'
STATUS_LINKACCT  = 'linkacct'
STATUS_PLACETILE = 'placetile'
STATUS_CONNERR   = 'connerr'
STATUS_DCONN     = 'dconn'
STATUS_COOLDOWN  = 'cooldown'

PALETTE = [
	[0x6D, 0x00, 0x1A, 0xFF],
	[0xBE, 0x00, 0x39, 0xFF],
	[0xFF, 0x45, 0x00, 0xFF],
	[0xFF, 0xA8, 0x00, 0xFF],
	[0xFF, 0xD6, 0x35, 0xFF],
	[0xFF, 0xF8, 0xB8, 0xFF],
	[0x00, 0xA3, 0x68, 0xFF],
	[0x00, 0xCC, 0x78, 0xFF],
	[0x7E, 0xED, 0x56, 0xFF],
	[0x00, 0x75, 0x6F, 0xFF],
	[0x00, 0x9E, 0xAA, 0xFF],
	[0x00, 0xCC, 0xC0, 0xFF],
	[0x24, 0x50, 0xA4, 0xFF],
	[0x36, 0x90, 0xEA, 0xFF],
	[0x51, 0xE9, 0xF4, 0xFF],
	[0x49, 0x3A, 0xC1, 0xFF],
	[0x6A, 0x5C, 0xFF, 0xFF],
	[0x94, 0xB3, 0xFF, 0xFF],
	[0x81, 0x1E, 0x9F, 0xFF],
	[0xB4, 0x4A, 0xC0, 0xFF],
	[0xE4, 0xAB, 0xFF, 0xFF],
	[0xDE, 0x10, 0x7F, 0xFF],
	[0xFF, 0x38, 0x81, 0xFF],
	[0xFF, 0x99, 0xAA, 0xFF],
	[0x6D, 0x48, 0x2F, 0xFF],
	[0x9C, 0x69, 0x26, 0xFF],
	[0xFF, 0xB4, 0x70, 0xFF],
	[0x00, 0x00, 0x00, 0xFF],
	[0x51, 0x52, 0x52, 0xFF],
	[0x89, 0x8D, 0x90, 0xFF],
	[0xD4, 0xD7, 0xD9, 0xFF],
	[0xFF, 0xFF, 0xFF, 0xFF],
]

################################################################################
# Globals

################################################################################
# Canvas positioning

window.g_pos = {

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# Position variables

	# X/Y coords of screen center
	x: null
	y: null

	# Floored versions of coords
	xf: null
	yf: null

	# Zoom index and zoom level
	zi: null
	zl: null

	# Valid values for zoom level
	zooms: [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 3, 5, 10]

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# Set position
	set: (x, y, zi) ->

		# Check for null values, which indicate to not change that coord
		x ?= this.x
		y ?= this.y
		zi ?= this.zi

		# Range checks and other validation
		if x < 0 then x = 0
		if y < 0 then y = 0
		if x >= BOARD_WIDTH  then x = BOARD_WIDTH  * (1 - Math.EPSILON)
		if y >= BOARD_HEIGHT then x = BOARD_HEIGHT * (1 - Math.EPSILON)
		zi = Math.floor zi
		if zi < 0 then zi = 0
		if zi >= this.zooms.length then zi = this.zooms.length - 1
		
		# Set values
		this.x = x
		this.y = y
		this.xf = Math.floor x
		this.yf = Math.floor y
		this.zi = zi
		this.zl = this.zooms[zi]

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# Add position
	add: (x, y, zi) -> this.set(x + this.x, y + this.y, zi + this.zi)

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Initialization

$ ->

	# Grab position data from cookie, set to defaults if needed
	x = $.cookie('posx')
	x ?= 1000.5
	y = $.cookie('posy')
	y ?= 1000.5
	zi = $.cookie('poszi')
	zi ?= 11

	# Initialize position
	g_pos.set x, y, zi

################################################################################
# Canvas movement & navigation

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Global variables

# Anchor X and Y coordinates, established when clicking down on the canvas
anchorX = null
anchorY = null

# Corresponding mouse coordinates for those X and Y coords
anchorMX = null
anchorMY = null

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Get raw transformation values
# txp, typ: transform along x/y as percentage
# sf: scale factor
# I did a LOT of experimentation to arrive at these numbers, and they seem to
# work just fine. I don't have a mathematical proof behind these though...

render_getRawTransform = (x, y, z) ->

	txp = (100.0 / 2000.0) * x
	typ = (100.0 / 2000.0) * y
	sf  = z * 10.0

	{txp: txp, typ: typ, sf: sf}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# From a raw mouse coordinate, grab cooresponding x/y coord on the canvas

render_getXYFromMouse = (mx, my) ->

	# Grab canvas bounding box, this will take transforms into consideration
	bb = $('canvas')[0].getBoundingClientRect()

	# Re-orient mouse coordinates to use top-left of canvas as origin
	xc = mx - bb.x
	yc = my - bb.y

	# Scale according to canvas dimensions
	xp = xc / bb.width
	yp = yc / bb.height

	# We now have coordinates as a percentage of canvas width/height
	# Multiply by number of pixels to get final result
	x = xp * BOARD_WIDTH
	y = yp * BOARD_HEIGHT

	# Scan for invalid outputs
	invalid = x < 0 or y < 0 or x >= BOARD_WIDTH or y >= BOARD_HEIGHT
	
	# Success
	{ x: x, y: y, invalid: invalid }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# From an x/y coord on the canvas, grab cooresponding raw mouse coordinate

render_getMouseFromXY = (x, y) ->

	# Grab canvas bounding box, this will take transforms into consideration
	bb = $('canvas')[0].getBoundingClientRect()

	# Get coords as percentage of canvas TODO
	xp = x / BOARD_WIDTH
	yp = y / BOARD_HEIGHT

	# Scale according to canvas dimensions
	xc = xp * bb.width
	yc = yp * bb.height

	# Re-orient mouse coordinates to correct for top-left of canvas
	mx = xc + bb.x
	my = yc + bb.y

	{ mx: mx, my: my }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Transform the canvas and relevant UI elements to reflect being positioned
# at the given X,Y coord with the given zoom.

render_applyPos = () ->

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Move the canvas parent to the correct spot

	# Grab raw transform values
	t = render_getRawTransform g_pos.x, g_pos.y, g_pos.zl

	# Format correctly and apply to element designed to handle these transforms
	# Other DOM elements will resize and move appropriately
	$('canvas').css 'transform', "scale(#{t.sf}) translate(-#{t.txp}%, -#{t.typ}%)"

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Update the XYZ UI element at the top

	$('.panel.pos-zoom').text "(#{g_pos.xf},#{g_pos.yf}) #{g_pos.zl}x"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Animate the pixel selection reticule

render_animateReticule = () ->

	# Retrieve coordinates for top-left and bottom-right
	tl = render_getMouseFromXY g_pos.xf, g_pos.yf
	br = render_getMouseFromXY 1 + g_pos.xf, 1 + g_pos.yf

	# As simple as moving the selction SVG's parent to the correct spot.
	$('.reticule').css {
		top:    tl.my + 'px'
		left:   tl.mx + 'px'
		width:  (br.my - tl.my) + 'px'
		height: (br.mx - tl.mx) + 'px'
	}

	window.requestAnimationFrame render_animateReticule

# Initial call to start animation loop
window.requestAnimationFrame render_animateReticule

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Handle mouse events
$ ->

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Process click-and-drag

	# Establish an anchor point upon mousedown
	$('body').on 'mousedown', (e) ->

		# Do not establish an anchor point if clicking on UI elements
		if $(e.target).is('.palette, .panel') || $(e.target).parents().is('.palette, .panel')
			anchorX = null
			anchorY = null
			anchorMX = null
			anchorMY = null
		
		else

			# Remove transition smoothing, we want to be responsive
			$('canvas').removeClass 'smooth-animation'

			# Establishing an anchor point
			anchorX = g_pos.x
			anchorY = g_pos.y
			anchorMX = e.originalEvent.x
			anchorMY = e.originalEvent.y
	
	# Re-add animation smoothing
	$('body').on 'mouseup', (e) ->
		$('canvas').addClass 'smooth-animation'
	
	# Set coords and open palette if clicked
	$('body').on 'click', (e) ->

		# If clicked on a single spot, center the canvas there
		if e.originalEvent.x == anchorMX and e.originalEvent.y == anchorMY

			# Obtain pixel that was clicked
			coords = render_getXYFromMouse anchorMX, anchorMY
			console.log coords

			# If clicked in the canvas, center on that location
			if !coords.invalid
				g_pos.set Math.floor(coords.x) + 0.5, Math.floor(coords.y) + 0.5, null
				render_applyPos()

				# Also show the palette if we can
				if ui_getStatus() == 'placetile'
					$('.palette').removeClass('hidden')

	# Use that anchor point when the mouse moves
	$('body').on 'mousemove', (e) ->
	
		# Only move if a mouse button is pressed and anchor was set
		if e.buttons and anchorX != null

			# How far away from the anchor is the mouse now?
			moveXpx = e.originalEvent.x - anchorMX
			moveYpx = e.originalEvent.y - anchorMY
			
			# Get the size of the element in pixels
			realsizeX = $('canvas').width()
			realsizeY = $('canvas').height()
			
			# Convert these coordinates in client space into a percentage of
			# the element. What percent of the element have we traversed since
			# mousedown?
			moveXratio = moveXpx / (realsizeX * 10.0 * g_pos.zl)
			moveYratio = moveYpx / (realsizeY * 10.0 * g_pos.zl)

			# Set position appropriately
			g_pos.set anchorX - (moveXratio * BOARD_WIDTH), anchorY - (moveYratio * BOARD_HEIGHT), null

			# Actually do the moving
			render_applyPos()

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Process scroll wheel
	
	$('body').on 'wheel', (e) ->

		# Determine zoom level to add from event
		zl_add = 0
		if e.originalEvent.deltaY < 0 then zl_add = +1
		if e.originalEvent.deltaY > 0 then zl_add = -1

		# Apply zoom to position
		g_pos.add 0, 0, zl_add

		# Remove smoothing
		$('canvas').removeClass 'smooth-animation'

		# Render the canvas zoom
		render_applyPos()

		# Re-establish anchor point if we're holding down a mouse button
		if e.buttons
			coord = render_getXYFromMouse e.originalEvent.x, e.originalEvent.y
			anchorX = g_pos.x
			anchorY = g_pos.y
			anchorMX = e.originalEvent.x
			anchorMY = e.originalEvent.y


		# Re-add smoothing if we're not holding a mouse button
		if !e.buttons then $('canvas').addClass 'smooth-animation'
	
	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Process mouse click

	$('canvas').on 'mouseup', (e) ->
		#console.log(e.originalEvent)

$ ->
	render_applyPos()

################################################################################
# Pallete Handling

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Helper functions

#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
# Clean and hide the palette UI

ui_clearPalette = () ->
	# Clean up the palette UI element and hide it

	# Disable submit button
	$('.palette form.submit button').attr('disabled', 'disabled')

	# De-select all colors
	$('.palette .colors .color').removeClass('selected')

	# Clear placement reticule color
	$('.reticule').css 'background-color', "transparent"

	# And hide the UI
	$('.palette').addClass('hidden')

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Initialization and event handling
$ ->

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Create all the color options from palette

	for k, v of PALETTE

		# Grab background color from palette
		rgb_bg = "rgb(#{v[0]},#{v[1]},#{v[2]})"

		# Same as background color, except for white
		rgb_bdr = if v[0] == v[1] == v[2] == 0xFF then "black" else rgb_bg

		# Append correctly-formatted element
		$('.palette .colors').append $("<div data-index='#{k}' class='color' style='background-color: #{rgb_bg}; border-color: #{rgb_bdr};'></div>")
	
	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Color event handling

	$('.palette .colors .color').on 'click', (e) ->

		# Ensure only the selected color is pressed
		$('.palette .colors .color').removeClass('selected')
		$(e.target).addClass('selected')

		# Change placement reticule to match selected color
		c = PALETTE[e.target.dataset.index]
		$('.reticule').css 'background-color', "rgb( #{c[0]}, #{c[1]}, #{c[2]} )"

		# Enable the submit button
		$('.palette form.submit button')[0].removeAttribute('disabled')
	
	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Button event handling

	#       #       #       #       #       #       #       #       #       #   
	# Cancel placement

	$('.palette form.cancel').on 'submit', (e) ->
		e.preventDefault()
		ui_clearPalette()
		false

	#       #       #       #       #       #       #       #       #       #   
	# Submit placement

	$('.palette form.submit').on 'submit', (e) ->
		e.preventDefault()

		# Craft and send a pixel-placement message

		ab = new ArrayBuffer(5)
		dv = new DataView(ab)

		# Set message header
		dv.setUint8(0, MSGTYPE_CPLACE)

		# Determine color
		c = $('.palette .colors .color.selected')[0].dataset.index

		# Create a packed pixel with color and position
		pixel = ((g_pos.xf + (g_pos.yf * BOARD_WIDTH)) << 8) | c

		# Plop the packed pixel in place
		dv.setUint32(1, pixel)

		# ... and send
		ws.send(dv)

		# Show timeout status
		ui_setStatus STATUS_COOLDOWN

		# Clean the palette UI
		ui_clearPalette()

		false

################################################################################
# Status Handling

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

ui_setStatus = (s, timeleft = RATELIMIT_SEC) ->

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Common preprocessing

	# Set dataset attribute right away
	$('.panel.status')[0].dataset.mode = s

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Special considerations

	# Do we need to widen the status bar?
	if s == STATUS_LINKACCT
		$('.panel.status').addClass 'wide'
	else
		$('.panel.status').removeClass 'wide'
	
	# Special handling for cooldown status
	if s == STATUS_COOLDOWN
		$('.panel.status').html "
			<img class='timeleft' src='/timer.svg' />
			<div class='timeleft'></div>
			"
		ui_handleCooldown(timeleft)
		return

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Show status to user

	$('.panel.status').text window.lang['status_' + s]['en']

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

ui_getStatus = () ->
	$('.panel.status')[0].dataset.mode

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Show cooldown message to user

ui_handleCooldown = (timeleft = RATELIMIT_SEC) ->

	intervalfn = () ->

		# Clear the interval if we don't need it anymore
		if timeleft <= 0
			$('.panel.status .timeleft').html ''
			window.clearTimeout interval
			ui_setStatus STATUS_PLACETILE
			return
		
		# Determine hours/minutes/seconds left
		h = Math.floor(timeleft / 3600)
		m = Math.floor((timeleft % 3600) / 60)
		s = Math.floor(timeleft % 60)

		# Add padding zeroes if needed
		hs = (if h < 10 then "0" else "") + h
		ms = (if m < 10 then "0" else "") + m
		ss = (if s < 10 then "0" else "") + s
		
		# Display the properly-formatted time left
		$('.panel.status .timeleft').html "#{hs}:#{ms}:#{ss}"

		# Decrement our time left
		timeleft--
	
	# Set the interval
	interval = window.setInterval intervalfn, 1000
	intervalfn()

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Initialization and event handling

$ ->

	ui_setStatus STATUS_LOADING

	$('.panel.status').on 'click', (e) ->
		
		switch ui_getStatus()

			#when STATUS_LOADING

			when STATUS_LINKACCT
				window.open(document.location.protocol + "//" + document.location.host + "/endpoint/link-reddit-account", "_blank").focus()

			when STATUS_PLACETILE
				$('.palette').removeClass('hidden')

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

# Pass a DataView into a MSGTYPE_HUPDATE message, and this function will
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
$ ->

	# Build out websocket URL
	wsurl = "ws://" + document.location.host + "/ws"
	if document.cookie then wsurl += "?session=" + $.cookie('session')

	# Establish Websocket connection
	window.ws = new WebSocket wsurl

	# Handle errors and closure
	window.ws.onerror = window.ws.onclose = (e) ->
		ui_setStatus STATUS_DCONN

	# Handle messages
	window.ws.onmessage = ({data}) ->
		data.arrayBuffer().then (raw) ->
			d = new DataView(raw)
			msgtype = d.getUint8 0

			# Process message
			switch msgtype

				# Receiving board for authenticated user
				when MSGTYPE_HBOARDAUTH

					# If we're not rate-limited, allow for pixel placement
					if ui_getStatus() != STATUS_COOLDOWN then ui_setStatus STATUS_PLACETILE

					# Show the board
					render_paintBoard d

				# User is not authenticated
				# Tell user to link account to proceed
				when MSGTYPE_HBOARDANON
					ui_setStatus STATUS_LINKACCT
					render_paintBoard d
				
				# Board update
				when MSGTYPE_HUPDATE
					render_updateBoard d
				
				# Ratelimit message
				when MSGTYPE_HRATELIMIT
					ui_setStatus STATUS_COOLDOWN, d.getUint32 1

