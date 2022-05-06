################################################################################
# /src/web/index/script/ui.coffee
# Handles the more technical aspects of rendering the UI

import $ from 'jquery'
import Cookie from 'js-cookie'

import Globals from './globals.coffee'

import * as Pos    from './pos.coffee'
import * as Status from './status.coffee'

################################################################################
# Exported variables

################################################################################
# Private variables

# Anchor X and Y coordinates in canvas space
# Established when clicking down on the canvas
l_anchorCX = null
l_anchorCY = null

# Corresponding screen space coordinates for those canvas space coords
l_anchorSX = null
l_anchorSY = null

################################################################################
# Exported functions

#///////////////////////////////////////////////////////////////////////////////
# Convert between canvas and screen space

# These two functions are inverses of each other
# TODO unit test? assert [x, y] == canvasToScreen screenToCanvas x, y

#===============================================================================

export canvasToScreen = (cx, cy) ->

	#---------------------------------------------------------------------------
	# Initialization

	# Grab canvas bounding box, this will take transforms into consideration
	# This variable is in screen space
	sbb = $('canvas.place')[0].getBoundingClientRect()

	#---------------------------------------------------------------------------
	# Conversion

	# How far are we into the canvas?
	# These coords are space-independent,
	# and start at 0 for the top-left and 1 for the bottom-right
	# I use p for percentage here, since they range from 0% (0) to 100% (1)
	xp = cx / Globals.BOARD_WIDTH
	yp = cy / Globals.BOARD_HEIGHT

	# Perform conversion into screen space
	# Scale according to canvas dimensions
	# Result is how many pixels the canvas space dimensions are into the
	# canvas from its origin at the top-left of the canvas
	sxc = xp * sbb.width
	syc = yp * sbb.height

	# Re-orient mouse coordinates to correct for top-left of canvas
	# and make them relative to the top-left of the screen instead
	# This is the final step
	sx: sxc + sbb.x
	sy: syc + sbb.y

#===============================================================================

export screenToCanvas = (sx, sy) ->

	#---------------------------------------------------------------------------
	# Initialization

	# Grab canvas bounding box, this will take transforms into consideration
	# This variable is in screen space
	sbb = $('canvas.place')[0].getBoundingClientRect()

	#---------------------------------------------------------------------------
	# Conversion

	# Re-orient screen coordinates to correct for the top-left of the screen
	# and make them relative to the canvas's top-left origin instead
	sxc = sx - sbb.x
	syc = sy - sbb.y

	# How far are we into the canvas?
	# These coordinates are a percentage from 0 to 1,
	# and are therefore space-independent
	xp = sxc / sbb.width
	yp = syc / sbb.height

	# Perform conversion into canvas space
	# Scale according to canvas dimensions in tiles
	cx = xp * Globals.BOARD_WIDTH
	cy = yp * Globals.BOARD_HEIGHT

	# Return to the user
	# Add a nice helper field to tell if coords fall on the canvas
	cx: cx
	cy: cy
	on_canvas: cx >= 0 and cy > 0 and cx < Globals.BOARD_WIDTH and cy < Globals.BOARD_HEIGHT

#///////////////////////////////////////////////////////////////////////////////
# Transform the canvas to reflect being positioned
# at the given X,Y coord with the given zoom.

export applyPos = (pos) ->

	#===========================================================================
	# Move the canvas parent to the correct spot

	# Grab raw transform values
	t = getRawCanvasTransform pos

	# Format correctly and apply to element designed to handle these transforms
	# Other DOM elements will resize and move appropriately
	$('canvas.place').css 'transform', "scale(#{t.sf}) translate(-#{t.txp}%, -#{t.typ}%)"

	#===========================================================================
	# Update the XYZ UI element at the top

	$('.panel.pos-zoom').text "(#{pos.xf},#{pos.yf}) #{pos.zl}x"

################################################################################
# Private functions

#///////////////////////////////////////////////////////////////////////////////
# Get raw transformation values
# txp, typ: transform along x/y as percentage
# sf: scale factor
# I did a LOT of experimentation to arrive at these numbers, and they seem to
# work just fine. I don't have a mathematical proof behind these though...
# TODO I really ought to unit test this.

getRawCanvasTransform = (pos) ->
	txp: (100.0 / 2000.0) * pos.x
	typ: (100.0 / 2000.0) * pos.y
	sf:   10.0            * pos.zl

#///////////////////////////////////////////////////////////////////////////////
# Determine if we should skip a mouse event
# Necessary since all events are attached to the BODY
# So don't zoom the canvas if we're scrolling on chat, for example

shouldSkipMouseEvent = (e) ->

	# A popup is open, let that take precedence
	if $('.popup:not(.-hidden)').length then return true

	# Source is the chat box, don't bother with that
	if $(e.target).add($(e.target).parents()).is('.chat-parent') then return true

	# Passed all checks, continue with processing the event
	false

#///////////////////////////////////////////////////////////////////////////////
# Animate various canvas-bound elements

animateUI = ->

	#===========================================================================
	# Pixel selection reticule

	# Get current position
	pos = Pos.val()

	# Retrieve coordinates for top-left and bottom-right
	# Reticule is one tile big
	tl = canvasToScreen pos.xf    , pos.yf
	br = canvasToScreen pos.xf + 1, pos.yf + 1

	# As simple as moving the selction SVG's parent to the correct spot
	# The image will wrap around the pixel correctly
	$('.reticule').css
		top:    tl.sy + 'px'
		left:   tl.sx + 'px'
		width:  (br.sx - tl.sx) + 'px'
		height: (br.sy - tl.sy) + 'px'

	#===========================================================================
	# Cleanup

	# I'LL DO IT AGAIN
	window.requestAnimationFrame animateUI

################################################################################
# Initialization

$ ->

	# Initialize position, which in turn updates the UI
	# Defaults to center of screen if pos cookies aren't set
	Pos.set Cookie.get('posx') ? 1000.5, Cookie.get('posy') ? 1000.5, Cookie.get('poszi') ? 6

	# Begin animation loop
	window.requestAnimationFrame animateUI

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Process click-and-drag

	#===========================================================================
	# Mousedown: Establish anchor point

	$('body').on 'mousedown', (e) ->

		# Erase anchor point if clicked on the wrong UI element
		# Would rather not establish an anchor point if user clicks on chatbox
		if shouldSkipMouseEvent(e) or $(e.target).add($(e.target).parents()).is('.palette, .panel')
			l_anchorCX = null
			l_anchorCY = null
			l_anchorSX = null
			l_anchorSY = null
		
		# Else, proceed with establishing anchor point
		else

			# Remove transition smoothing, we want to be responsive
			$('canvas.place').removeClass '-smooth-animation'

			# Get current position
			pos = Pos.val()

			# Establishing an anchor point
			l_anchorCX = pos.x
			l_anchorCY = pos.y
			l_anchorSX = e.originalEvent.x
			l_anchorSY = e.originalEvent.y
	
	#===========================================================================
	# Mouseup: Re-apply animation smoothing

	$('body').on 'mouseup', (e) ->

		#if shouldSkipMouseEvent(e) then return

		# Re-apply animation smoothing
		$('canvas.place').addClass '-smooth-animation'
	
	#===========================================================================
	# Click: Open pallete and set coords

	$('body').on 'click', (e) ->

		if shouldSkipMouseEvent(e) then return

		# Only applies if click's mousedown coords were same as mouseup coords
		# If we click in one spot, drag over to a new spot, then release,
		# that still fires a click event
		# Don't process those events, that's silly
		if e.originalEvent.x == l_anchorSX and e.originalEvent.y == l_anchorSY

			# We're performing a click, not a drag
			# Re-apply smoothing
			#$('canvas.place').addClass '-smooth-animation'

			# Obtain tile that was clicked in canvas space
			ccoords = screenToCanvas l_anchorSX, l_anchorSY

			# If clicked in the canvas, center on that location
			if ccoords.on_canvas
				Pos.set Math.floor(ccoords.cx) + 0.5, Math.floor(ccoords.cy) + 0.5, null

				# Also show the palette if we can
				if Status.get() is Status.PLACETILE
					$('.palette').removeClass('-hidden')

	#===========================================================================
	# Mousemove: Move canvas using anchor as reference

	$('body').on 'mousemove', (e) ->
	
		#if shouldSkipMouseEvent(e) then return

		# Only move if a mouse button is pressed and anchor was set
		if e.buttons and l_anchorCX != null

			# TODO actually go through and understand why this works

			# Get current position (for zoom level)
			pos = Pos.val()

			# How far away from the anchor is the mouse now?
			moveXpx = e.originalEvent.x - l_anchorSX
			moveYpx = e.originalEvent.y - l_anchorSY
			
			# Get the size of the element in pixels
			realsizeX = $('canvas.place').width()
			realsizeY = $('canvas.place').height()
			
			# Convert these coordinates in client space into a percentage of
			# the element. What percent of the element have we traversed since
			# mousedown?
			moveXratio = moveXpx / (realsizeX * 10.0 * pos.zl)
			moveYratio = moveYpx / (realsizeY * 10.0 * pos.zl)

			# Set position appropriately
			Pos.set l_anchorCX - (moveXratio * Globals.BOARD_WIDTH), l_anchorCY - (moveYratio * Globals.BOARD_HEIGHT), null

	#///////////////////////////////////////////////////////////////////////////////
	# Process scroll wheel
	
	$('body').on 'wheel', (e) ->

		if shouldSkipMouseEvent(e) then return

		# Determine zoom level to add from event
		# TODO apparently some mice send different deltaY's than others?
		# Like an apple mouse would send a million wheel events when scrolling,
		# and not just one per bump on the mouse wheel?
		# LOOK INTO THIS, current implentation would majorly suck for apple users
		zldelta = 0
		if e.originalEvent.deltaY < 0 then zldelta = +1
		if e.originalEvent.deltaY > 0 then zldelta = -1

		# Update position and retrieve
		Pos.add 0, 0, zldelta
		pos = Pos.val()

		# Re-establish anchor point if we're holding down a mouse button
		# Smoothing should have been disabled by the mouse-down event already
		if e.buttons
			l_anchorCX = pos.x
			l_anchorCY = pos.y
			l_anchorSX = e.originalEvent.x
			l_anchorSY = e.originalEvent.y

