################################################################################
# Constants
# Must be kept the same as the ones used by the server

BOARD_WIDTH  = 2000
BOARD_HEIGHT = 2000
Z = [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 3, 4, 5]

MSGTYPE_HBOARD  = 0x10
MSGTYPE_HUPDATE = 0x11

MSGTYPE_CPLACE = 0x20

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
# Canvas movement & navigation

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Global variables

# X and Y coordinates for where the canvas should be positioned under
X = 1000.5
Y = 1000.5

# Zoom level, maps to an index in Z
Z_LVL = 6

# Anchor X and Y coordinates, established when clicking down on the canvas
anchorX = null
anchorY = null

# Corresponding mouse coordinates for those X and Y coords
anchorMX = null
anchorMY = null

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
window.render_applyPositionScale = (x, y, zoom) =>
	# Transform the canvas and relevant UI elements to reflect being positioned
	# at the given X,Y coord with the given zoom.

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Move the canvas parent to the correct spot

	# Do not apply transformations to the canvas element directly!
	# Apply to .canvas-transform which is designed to handle transformations
	# The rest of the DOM is styled to maintain their look if the parent
	# is scaled/moved
	# We need to do some non-trivial calculations to determine exactly what
	# the transform string should be, so use an IIFE
	# It took a LOT of fiddling to get this right. I don't have much in solid
	# maths/proofs behind all this, but I did mess with it quite a bit,
	# and it seems to work just fine as-is.
	$('.canvas-transform').css 'transform', do (x, y, zoom) ->

		scaleFromZoom = (zoom) ->
			scale = zoom * 0.01
			"scale(#{scale}) "
		
		translateFromXY = (x, y) ->
			tx_x = (100.0 / 2000.0) * x
			tx_y = (100.0 / 2000.0) * y
			"translate(-#{tx_x}%, -#{tx_y}%) "
		
		scaleFromZoom(zoom) + translateFromXY(x, y)

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Move the pixel selection to the correct spot

	# As simple as moving the selction SVG to the correct spot.
	# The canvas parent transform already did most of the hard work.
	# Again, canvas is 500000vmin wide/tall and has 2000x2000 px.
	# We floor x and y here to snap the selection to a grid.
	$('.img-select-parent').css {
		left: ((500000.0 / BOARD_WIDTH ) * Math.floor(x)) + 'vmin' 
		top:  ((500000.0 / BOARD_HEIGHT) * Math.floor(y)) + 'vmin'
	}

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Update the XYZ UI element at the top

	$('.panel.pos-zoom').text "(" + Math.floor(X) + "," + Math.floor(Y) + ") " + Z[Z_LVL] + "x"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Handle mouse events
$ ->

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Process click-and-drag

	# Establish an anchor point upon mousedown
	$('body').on 'mousedown', (e) ->

		# Do not establish an anchor point if clicking on UI elements
		if $(e.target).parents().is('.palette, .panel')
			anchorX = null
			anchorY = null
			anchorMX = null
			anchorMY = null
		
		else
			anchorX = X
			anchorY = Y
			anchorMX = e.originalEvent.x
			anchorMY = e.originalEvent.y
	
	# Set coords and open palette if clicked
	$('body').on 'click', (e) ->
		console.log e

		if e.originalEvent.x == anchorMX and e.originalEvent.y == anchorMY

			# TODO set coords

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
			realsizeX = $('.canvas-transform').width()
			realsizeY = $('.canvas-transform').height()
			
			# Convert these coordinates in client space into a percentage of
			# the element. What percent of the element have we traversed since
			# mousedown?
			moveXratio = moveXpx / (realsizeX * 0.01 * Z[Z_LVL])
			moveYratio = moveYpx / (realsizeY * 0.01 * Z[Z_LVL])

			# Set position appropriately
			X = anchorX - (moveXratio * BOARD_WIDTH)
			Y = anchorY - (moveYratio * BOARD_HEIGHT)

			# Boundary checking
			# TODO put this somewhere better, maybe make a class with set/get
			if X < 0
				X = 0
			if Y < 0
				Y = 0
			if X >= BOARD_WIDTH
				X = BOARD_WIDTH - (Number.EPSILON * BOARD_WIDTH)
			if Y >= BOARD_HEIGHT
				Y = BOARD_HEIGHT - (Number.EPSILON * BOARD_HEIGHT)

			# Actually do the moving
			render_applyPositionScale(X, Y, Z[Z_LVL])

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Process scroll wheel
	
	$('body').on 'wheel', (e) ->

		# Zoom in and out appropriately if we can
		if (e.originalEvent.deltaY < 0) && (Z_LVL < Z.length - 1)
			Z_LVL += 1
		if (e.originalEvent.deltaY > 0) && (Z_LVL > 0)
			Z_LVL -= 1
		
		# Render the canvas zoom
		render_applyPositionScale(X, Y, Z[Z_LVL])
	
	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Process mouse click

	$('canvas').on 'mouseup', (e) ->
		#console.log(e.originalEvent)

$ ->
	render_applyPositionScale(X, Y, Z[Z_LVL])

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
	$('.canvas-parent .img-select-parent').css 'background-color', "transparent"

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
		$('.canvas-parent .img-select-parent').css 'background-color', "rgb( #{c[0]}, #{c[1]}, #{c[2]} )"

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

		# Determine coordinates and color
		x = Math.floor X
		y = Math.floor Y
		c = $('.palette .colors .color.selected')[0].dataset.index

		# Create a packed pixel with this data
		pixel = ((x + (y * BOARD_WIDTH)) << 8) | c

		# Plop the packed pixel in place
		dv.setUint32(1, pixel)

		# ... and send
		ws.send(dv)

		# Clean the palette UI
		ui_clearPalette()

		false

################################################################################
# Status Handling

ui_setStatus = (s) ->

	if s == 'linkacct'
		$('.panel.status').addClass 'wide'
	else
		$('.panel.status').removeClass 'wide'

	$('.panel.status').text window.lang['status_' + s]['en']
	$('.panel.status')[0].dataset.mode = s

ui_getStatus = () ->
	$('.panel.status')[0].dataset.mode

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Event handling

$ ->

	$('.panel.status').on 'click', (e) ->
		
		switch ui_getStatus()

			#when 'loading'

			when 'linkacct'
				window.open(document.location.protocol + "//" + document.location.host + "/endpoint/link-reddit-account", "_blank").focus()

			when 'placetile'
				$('.palette').removeClass('hidden')
			

################################################################################
# Webpage Initialization

$ ->

	ui_setStatus('loading')

$ ->

	window.ws = new WebSocket("ws://" + document.location.host + "/ws")

	window.ws.onmessage = ({data}) ->
		data.arrayBuffer().then (raw) ->
			d = new DataView(raw)

			switch d.getUint8 0

				when MSGTYPE_HBOARD
					
					# Grab canvas context and image data
					cx = $('canvas')[0].getContext '2d'
					id = cx.getImageData 0, 0, BOARD_WIDTH, BOARD_HEIGHT

					# Process each color code passed to us
					for i in [0 ... BOARD_WIDTH * BOARD_HEIGHT]
						cc = d.getUint8 i + 1
						id.data.set PALETTE[cc], i * 4
					
					# Put image data
					cx.putImageData id, 0, 0

					# Update the app status
					ui_setStatus("linkacct")

				when MSGTYPE_HUPDATE

					# Grab canvas context and image data
					cx = $('canvas')[0].getContext '2d'
					id = cx.getImageData 0, 0, BOARD_WIDTH, BOARD_HEIGHT
					console.log d

					# Process each color code passed to us
					for i in [1 ... d.byteLength ] by 4
						pack = d.getUint32 i
						x = Math.floor (pack >> 8) % BOARD_WIDTH
						y = Math.floor (pack >> 8) / BOARD_WIDTH
						c = Math.floor (pack >> 0) & 0xFF
						id.data.set PALETTE[c], 4 * (x + (y * BOARD_WIDTH))

					# Put image data
					cx.putImageData id, 0, 0

