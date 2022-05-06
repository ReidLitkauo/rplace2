################################################################################
# /src/web/index/script/bot.coffee
# Responsible for image placement via bot (and admin image insta-place)

jsdom = require('jsdom')
$ = if window? then require('jquery') else require('jquery')(new jsdom.JSDOM().window)
import UPNG from 'upng-js'

import Globals from './globals.coffee'

import * as Palette from './palette.coffee'
import * as Pos     from './pos.coffee'
import * as Status  from './status.coffee'
import * as Ui      from './ui.coffee'
import * as Ws      from './ws.coffee'

################################################################################
# Exported variables

################################################################################
# Private variables

# Raw image color code data
l_imgcc = null

# Image position
l_x = l_y = 0

# Image width and height
l_w = l_h = 0

# Stores return from setTimeout
l_timeout = null

# TODO add transparency skip
# TODO restore full pos movement when bot start
# TODO fix status upon bot start

################################################################################
# Exported functions

#///////////////////////////////////////////////////////////////////////////////
# Start the bot's main loop

export start = ->

	# Empty bot canvas, but keep the border
	$('canvas.bot')[0].getContext('2d').clearRect 0, 0, l_w, l_h

	# Show pixel selection reticule
	$('.reticule').removeClass '-hidden'

	# Reset min/max allowable position to allow free roaming
	# Also grab the current position while we're at it
	Pos.min()
	Pos.max()
	pos = Pos.val()

	# Set position of image's top-left
	[l_x, l_y] = getTopLeft pos

	# Begin main bot loop
	l_timeout = window.setTimeout placementLoop, if Globals.cooldown? then 1000 * Globals.cooldown else 0

	# Set cooldown to max
	Globals.cooldown = Globals.RATELIMIT_SEC

	# Set appropriate status
	Status.set Status.BOTRUN

#///////////////////////////////////////////////////////////////////////////////
# Stop running the bot and clear all bot-related UI

export cancel = ->

	#===========================================================================
	# Stop loop and clear data

	# Cancel bot loop
	if l_timeout? then window.clearTimeout l_timeout
	l_timeout = null

	# Erase stored data
	l_imgcc = null
	l_x = l_y = 0
	l_w = l_h = 0

	#===========================================================================
	# Update the UI

	# Show bot icon again
	$('.panel.button.bot').removeClass 'cancel'

	# Set canvas size to 0
	$('canvas.bot').prop('width', 0).prop('height', 0)

	# Hide the bot canvas, re-show pixel placement reticule
	$('canvas.bot').addClass '-hidden'
	$('.reticule').removeClass '-hidden'

	# Reset min/max position to restore full movement
	Pos.min()
	Pos.max()

	#===========================================================================
	# Switch status

	# Switch status appropriately
	switch Globals.role

		# Admins can always place a new tile
		when Globals.ROLE_ADMN
			Status.set Status.PLACETILE
		
		# Normal users must respect the cooldown
		when Globals.ROLE_AUTH
			if Globals.cooldown then Status.set Status.COOLDOWN, Globals.cooldown
			else                     Status.set Status.PLACETILE

#///////////////////////////////////////////////////////////////////////////////
# Used by admins to insta-place images

export instaplace = ->

	# Retrieve x,y coords for image top-left
	[l_x, l_y] = getTopLeft Pos.val()

	# Send image placement message
	Ws.sendImage l_x, l_y, l_w, l_h, l_imgcc

	# Reset the UI
	cancel()


################################################################################
# Private functions

#///////////////////////////////////////////////////////////////////////////////
# Bot main loop

placementLoop = ->

	# Iterate through image, row by row then pixel by pixel
	# These variables are in image space, NOT canvas space
	for iy in [0 ... h] then for ix in [0 ... w]

		# Grab index of pixel in image space and canvas space
		ii =  ix           + ( iy           * l_w)
		ci = (ix + l_x) + ((iy + l_y) * Globals.BOARD_WIDTH)

		# Skip transparent pixels
		# TODO 255 is a sentinel value, maybe throw that in a constant
		if l_imgcc[ii] == 255 then continue

		# Compare image color code to board color code
		# If not equal, send pixel message making it equal,
		# set next iteration, then return to start over in 10 seconds
		# plus a bit of a cushion just in case
		if Globals.board[ci] isnt l_imgcc[ii]
			Ws.sendPixel ix + l_x, iy + l_y, l_imgcc[ii]
			return l_timeout = window.setTimeout placementLoop, (Globals.RATELIMIT_SEC * 1000) + 50

	# If we made it here, then all pixels match already
	# Wait a little bit and try again
	l_timeout = window.setTimeout placementLoop, 100

#///////////////////////////////////////////////////////////////////////////////
# Get coordinates for top-left of image in canvas space,
# given its center in canvas space

getTopLeft = (pos) -> [
	pos.xf - Math.floor l_w / 2
	pos.yf - Math.floor l_h / 2
]

#///////////////////////////////////////////////////////////////////////////////
# Animate bot-placement canvas

animateUI = ->

	# Get top-left of image in canvas space
	# If we're actively placing, lock canvas in place and use existing coords
	# If not, let the user position the canvas based on focused pixel (center)
	[cx, cy] = if l_timeout? then [l_x, l_y] else getTopLeft Pos.val()

	# Convert top-left and bottom-right to screen space
	tl = Ui.canvasToScreen cx      , cy
	br = Ui.canvasToScreen cx + l_w, cy + l_h

	# Get width of border so we can account for it when positioning
	border_width = parseInt $('canvas.bot').css('border-width').slice 0, -2

	# Position canvas appropriately
	$('canvas.bot').css
		top:    (tl.sy - border_width) + 'px'
		left:   (tl.sx - border_width) + 'px'
		width:  (br.sx - tl.sx) + 'px'
		height: (br.sy - tl.sy) + 'px'

	# Start all over next frame
	window.requestAnimationFrame animateUI

################################################################################
# Initialization

$ ->

	# Start the bot animation loop
	window.requestAnimationFrame animateUI

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Click the bot: Begin bot placement flow

	$('.panel.button.bot').on 'click', (e) ->

		#=======================================================================
		# Step 0: Check for alternate states

		switch Status.get()

			#-------------------------------------------------------------------
			# Cancel placement if we're positioning or running the bot

			when Status.BOTPOS, Status.BOTRUN
				cancel()
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
			if !e.target.files.length then cancel()

			#===================================================================
			# Step 2: Process image

			#-------------------------------------------------------------------
			# Decode image and extract metadata

			# TODO error handling
			img = UPNG.decode await e.target.files[0].arrayBuffer()

			# Convert image to RGBA values
			iml_rgba = UPNG.toRGBA8(img)[0]

			# And get a data view
			iml_dv = new DataView iml_rgba

			# Store width and height for later
			l_w = img.width
			l_h = img.height

			# Array of color codes for this image, stored for later
			l_imgcc = new Uint8Array l_w * l_h

			#-------------------------------------------------------------------
			# Convert to color codes

			# Palette as a 1D array, also in RGBA format
			# For easy comparision against the uint32's we'll be
			# pulling out of the image
			palette1d = new Uint32Array Palette.PALETTE.length
			for i in [0 ... Palette.PALETTE.length]
				c = Palette.PALETTE[i]
				palette1d[i] = c[0] << 24 | c[1] << 16 | c[2] << 8 | c[3] << 0

			# Loop over all pixels
			for i in [0 ... l_imgcc.length]

				# Get color code for this pixel
				rgba = iml_dv.getUint32 i*4
				cc = palette1d.indexOf rgba

				# If this is a valid color, set value appropriately
				if cc != -1 then l_imgcc[i] = cc

				# If this is an invalid color, set to transparent
				# and treat as if it doesn't exist
				else
					l_imgcc[i] = 0xFF
					iml_dv.setUint32 i*4, 0x00000000

			#===================================================================
			# Step 3: Display and position image

			#-------------------------------------------------------------------
			# Position and draw image

			# Set bot canvas properties
			$('canvas.bot').prop('width', l_w).prop('height', l_h)

			# Draw onto image
			# This took a LOT of fiddling to get right
			canvas_data = $('canvas.bot')[0].getContext('2d').getImageData 0, 0, l_w, l_h
			canvas_data.data.set new Uint8Array iml_rgba
			$('canvas.bot')[0].getContext('2d').putImageData canvas_data, 0, 0

			#-------------------------------------------------------------------
			# Misc

			# Set min/max position to not draw over the edge
			# TODO +1 seems wrong
			Pos.min Math.floor(l_w / 2), Math.floor(l_h / 2)
			Pos.max Globals.BOARD_WIDTH - Math.ceil(l_w / 2) + 1, Globals.BOARD_HEIGHT - Math.ceil(l_h / 2) + 1

			# Show canvas, hide pixel placement reticule
			$('canvas.bot').removeClass '-hidden'
			$('.reticule').addClass '-hidden'

			# Display X over bot
			$('.panel.button.bot').addClass 'cancel'

			# Set status appropriately
			Status.set Status.BOTPOS
