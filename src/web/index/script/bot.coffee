################################################################################
# Globals

# Raw image color code data
l_imgcc = null

# Image position
l_x = l_y = 0

# Image width and height
l_w = l_h = 0

# Bot timeout
l_timeout = null

# TODO add transparency skip
# TODO restore full pos movement when bot start
# TODO fix status upon bot start

################################################################################
# Helper functions

#///////////////////////////////////////////////////////////////////////////////
# Start the bot's main loop

bot_start = ->

	# Empty bot canvas, but keep the border
	$('canvas.bot')[0].getContext('2d').clearRect 0, 0, l_w, l_h

	# Show pixel selection reticule
	$('.reticule').removeClass '-hidden'

	# Reset min/max allowable position to allow free roaming
	g_pos.setMin().setMax()

	# Set position
	l_x = g_pos.xf - Math.floor l_w / 2
	l_y = g_pos.yf - Math.floor l_h / 2

	# Begin main bot loop
	l_timeout = window.setTimeout bot_loop, if g_cooldown? then 1000 * g_cooldown else 0

	# Set cooldown to max
	g_cooldown = RATELIMIT_SEC

	# Set appropriate status
	status_set STATUS_BOTRUN

#///////////////////////////////////////////////////////////////////////////////
# Bot main loop

bot_loop = ->

	# Iterate through image, row by row then pixel by pixel
	for y in [0 ... l_h] then for x in [0 ... l_w]

		# Grab index of pixel in bot space and canvas space
		bi =  x        + ( y        * l_w)
		ci = (x + l_x) + ((y + l_y) * BOARD_WIDTH)

		# Skip transparent pixels
		if l_imgcc[bi] == 255 then continue

		# Compare image color code to board color code
		# If not equal, send pixel message making it equal,
		# set next iteration, then return
		if g_board[ci] isnt l_imgcc[bi]
			ws_send_putPixel x + l_x, y + l_y, l_imgcc[bi]
			return l_timeout = window.setTimeout bot_loop, (RATELIMIT_SEC * 1000) + 50

	# If we made it here, then all pixels match already
	# Wait a little bit and try again
	l_timeout = window.setTimeout bot_loop, 100

#///////////////////////////////////////////////////////////////////////////////
# Stop running the bot and clear all bot-related UI

bot_cancel = ->

	# Cancel bot loop
	if l_timeout? then window.clearTimeout l_timeout
	l_timeout = null

	# Erase stored data
	l_imgcc = null
	l_x = l_y = 0
	l_w = l_h = 0

	# Show bot icon again
	$('.panel.button.bot').removeClass 'cancel'

	# Set canvas size to 0
	$('canvas.bot').prop('width', 0).prop('height', 0)

	# Hide the bot canvas, re-show pixel placement reticule
	$('canvas.bot').addClass '-hidden'
	$('.reticule').removeClass '-hidden'

	# Reset min/max position to restore full movement
	g_pos.setMin().setMax()

	# Switch status appropriately
	switch g_role

		when ROLE_ADMN
			status_set STATUS_PLACETILE
		
		when ROLE_AUTH
			if g_cooldown then status_set STATUS_COOLDOWN, g_cooldown
			else               status_set STATUS_PLACETILE

#///////////////////////////////////////////////////////////////////////////////
# Used by admins to insta-place images

bot_place = ->

	# Retrieve x,y coords for image top-left
	l_x = g_pos.xf - Math.floor l_w / 2
	l_y = g_pos.yf - Math.floor l_h / 2

	# Send image placement message
	ws_send_putImage l_x, l_y, l_w, l_h, l_imgcc

	# Nothing to do here
	bot_cancel()

#///////////////////////////////////////////////////////////////////////////////
# Animate bot-placement canvas

bot_animateUI = ->

	# Grab width and height
	w = $('canvas.bot').prop 'width'
	h = $('canvas.bot').prop 'height'

	# Determine center offset from top-left so image renders in center
	offx = Math.floor w/2
	offy = Math.floor h/2

	# Retrieve coordinates for top-left and bottom-right

	# If we're actively placing, lock canvas in place
	if l_timeout?
		tl = canvas_getMouseFromXY l_x      , l_y
		br = canvas_getMouseFromXY l_x + l_w, l_y + l_h

	# If we're not actively placing anything, let the user position the canvas
	else
		tl = canvas_getMouseFromXY g_pos.xf - offx    , g_pos.yf - offy
		br = canvas_getMouseFromXY g_pos.xf - offx + w, g_pos.yf - offy + h

	# Position canvas appropriately
	$('canvas.bot').css {
		top:    (tl.my - 3) + 'px'
		left:   (tl.mx - 3) + 'px'
		width:  (br.mx - tl.mx) + 'px'
		height: (br.my - tl.my) + 'px'
	}

	window.requestAnimationFrame bot_animateUI

################################################################################
# Initialization

$ ->

	# Start the bot animation loop
	window.requestAnimationFrame bot_animateUI

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Click the bot: Begin bot placement flow

	$('.panel.button.bot').on 'click', (e) ->

		#=======================================================================
		# Step 0: Check for alternate states

		switch status_get()

			#-------------------------------------------------------------------
			# Cancel placement if we're positioning or running the bot

			when STATUS_BOTPOS, STATUS_BOTRUN
				bot_cancel()
				return false

		#=======================================================================
		# Step 1: Select an image file

		# Create a new file selection element
		fsel = $("<input type='file' accept='image/png'>")

		# Simulate a click to open file select dialog
		fsel.click()

		# Set callback to run when user selects a file
		fsel.on 'change', (e) ->

			# If no file was selected
			if !e.target.files.length then bot_cancel()

			#===================================================================
			# Step 2: Process image

			#-------------------------------------------------------------------
			# Decode image

			# TODO error handling
			img = UPNG.decode await e.target.files[0].arrayBuffer()

			# Array of color codes for this image, stored for later
			l_imgcc = new Uint8Array img.width * img.height

			# Convert image to RGBA values
			img_rgba = UPNG.toRGBA8(img)[0]

			# And get a data view
			img_dv = new DataView img_rgba

			# Also store image width and height for later
			l_w = img.width
			l_h = img.height

			#-------------------------------------------------------------------
			# Convert to color codes

			# Loop over all pixels
			for i in [0 ... l_imgcc.length]

				# Get color code for this pixel
				rgba = img_dv.getUint32 i*4
				cc = PALETTE_INTS.indexOf rgba

				# If this is a valid color, set value appropriately
				if cc != -1 then l_imgcc[i] = cc

				# If this is an invalid color, set to transparent
				# and treat as if it doesn't exist
				else
					l_imgcc[i] = 0xFF
					img_dv.setUint32 i*4, 0x00000000

			#===================================================================
			# Step 3: Display and position image

			#-------------------------------------------------------------------
			# Position and draw image

			# Set bot canvas properties
			$('canvas.bot').prop('width', img.width).prop('height', img.height)

			# Draw onto image
			# This took a LOT of fiddling to get right
			canvas_data = $('canvas.bot')[0].getContext('2d').getImageData 0, 0, img.width, img.height
			canvas_data.data.set new Uint8Array img_rgba
			$('canvas.bot')[0].getContext('2d').putImageData canvas_data, 0, 0

			#-------------------------------------------------------------------
			# Misc

			# Set min/max position to not draw over the edge
			# TODO +1 seems wrong
			g_pos.setMin Math.floor(img.width / 2), Math.floor(img.height / 2)
			g_pos.setMax BOARD_WIDTH - Math.ceil(img.width / 2) + 1, BOARD_HEIGHT - Math.ceil(img.height / 2) + 1

			# Show canvas, hide pixel placement reticule
			$('canvas.bot').removeClass '-hidden'
			$('.reticule').addClass '-hidden'

			# Display X over bot
			$('.panel.button.bot').addClass 'cancel'

			# Set status appropriately
			status_set STATUS_BOTPOS
