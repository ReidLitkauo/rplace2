################################################################################
# /src/web/index/script/palette.coffee
# Handles everything related to the palette at the bottom of the screen

import $ from 'jquery'

import Globals from './globals.coffee'

import * as Pos    from './pos.coffee'
import * as Status from './status.coffee'
import * as Ws     from './ws.coffee'

################################################################################
# Exported variables

# Palette as a 2D array
# In RGBA format
export PALETTE = [
	[0x6D, 0x00, 0x1A, 0xFF]
	[0xBE, 0x00, 0x39, 0xFF]
	[0xFF, 0x45, 0x00, 0xFF]
	[0xFF, 0xA8, 0x00, 0xFF]
	[0xFF, 0xD6, 0x35, 0xFF]
	[0xFF, 0xF8, 0xB8, 0xFF]
	[0x00, 0xA3, 0x68, 0xFF]
	[0x00, 0xCC, 0x78, 0xFF]
	[0x7E, 0xED, 0x56, 0xFF]
	[0x00, 0x75, 0x6F, 0xFF]
	[0x00, 0x9E, 0xAA, 0xFF]
	[0x00, 0xCC, 0xC0, 0xFF]
	[0x24, 0x50, 0xA4, 0xFF]
	[0x36, 0x90, 0xEA, 0xFF]
	[0x51, 0xE9, 0xF4, 0xFF]
	[0x49, 0x3A, 0xC1, 0xFF]
	[0x6A, 0x5C, 0xFF, 0xFF]
	[0x94, 0xB3, 0xFF, 0xFF]
	[0x81, 0x1E, 0x9F, 0xFF]
	[0xB4, 0x4A, 0xC0, 0xFF]
	[0xE4, 0xAB, 0xFF, 0xFF]
	[0xDE, 0x10, 0x7F, 0xFF]
	[0xFF, 0x38, 0x81, 0xFF]
	[0xFF, 0x99, 0xAA, 0xFF]
	[0x6D, 0x48, 0x2F, 0xFF]
	[0x9C, 0x69, 0x26, 0xFF]
	[0xFF, 0xB4, 0x70, 0xFF]
	[0x00, 0x00, 0x00, 0xFF]
	[0x51, 0x52, 0x52, 0xFF]
	[0x89, 0x8D, 0x90, 0xFF]
	[0xD4, 0xD7, 0xD9, 0xFF]
	[0xFF, 0xFF, 0xFF, 0xFF]
]

################################################################################
# Private variables

################################################################################
# Exported functions

#///////////////////////////////////////////////////////////////////////////////
# Open palette

export open = -> $('.palette').removeClass('-hidden')

#///////////////////////////////////////////////////////////////////////////////
# Close palette: Clean and hide palette UI

export close = ->

	# Disable submit button
	$('.palette form.submit button').attr('disabled', 'disabled')

	# De-select all colors
	$('.palette .colors .color').removeClass('selected')

	# Clear placement reticule color
	$('.reticule').css 'background-color', "transparent"

	# And hide the UI
	$('.palette').addClass('-hidden')

################################################################################
# Private functions

################################################################################
# Initialization

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Create all color options from palette constant

	for k, v of PALETTE

		# Grab background color from palette
		rgb_bg = "rgb(#{v[0]},#{v[1]},#{v[2]})"

		# Same as background color, except for white, which has black border
		rgb_bdr = if v[0] == v[1] == v[2] == 0xFF then "black" else rgb_bg

		# Append correctly-formatted element
		# The data-index is a special tool that will help us later ;3
		$('.palette .colors').append $("<div data-index='#{k}' class='color' style='background-color: #{rgb_bg}; border-color: #{rgb_bdr};'></div>")

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Clicked a color: Mark it as selected

	$('.palette .colors .color').on 'click', (e) ->

		# Ensure only the selected color is pressed
		$('.palette .colors .color').removeClass('selected')
		$(e.target).addClass('selected')

		# Change placement reticule to match selected color
		c = PALETTE[e.target.dataset.index]
		$('.reticule').css 'background-color', "rgb( #{c[0]}, #{c[1]}, #{c[2]} )"

		# Enable the submit button
		$('.palette form.submit button')[0].removeAttribute('disabled')
	
	#///////////////////////////////////////////////////////////////////////////
	# Clicked cancel button: Remove color selection and hide palette UI

	$('.palette form.cancel').on 'submit', (e) ->
		e.preventDefault()
		close()
		false

	#///////////////////////////////////////////////////////////////////////////
	# Clicked submit button: Send pixel to server and hide palette UI
	# Submit placement

	$('.palette form.submit').on 'submit', (e) ->
		e.preventDefault()

		#=======================================================================
		# Send a pixel-placement message

		pos = Pos.val()

		Ws.sendPixel pos.xf, pos.yf, $('.palette .colors .color.selected')[0].dataset.index

		#=======================================================================
		# Update the UI

		# Show appropriate follow-up status
		if Globals.role is Globals.ROLE_ADMN then Status.set Status.PLACETILE
		if Globals.role is Globals.ROLE_AUTH then Status.set Status.COOLDOWN

		# Clean the palette UI for non-admin users
		if Globals.role isnt Globals.ROLE_ADMN then close()

		false

