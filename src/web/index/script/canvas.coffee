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

	#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   
	# Miscellany

	# Prevent artifacting/smearing
	# https://stackoverflow.com/q/8840580
	# TODO nothing worked :(

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

