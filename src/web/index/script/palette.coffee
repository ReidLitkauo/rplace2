################################################################################
# Helper functions

#///////////////////////////////////////////////////////////////////////////////
# Clean and hide the palette UI

palette_clearUI = ->

	# Disable submit button
	$('.palette form.submit button').attr('disabled', 'disabled')

	# De-select all colors
	$('.palette .colors .color').removeClass('selected')

	# Clear placement reticule color
	$('.reticule').css 'background-color', "transparent"

	# And hide the UI
	$('.palette').addClass('-hidden')

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
		palette_clearUI()
		false

	#///////////////////////////////////////////////////////////////////////////
	# Clicked submit button: Send pixel to server and hide palette UI
	# Submit placement

	$('.palette form.submit').on 'submit', (e) ->
		e.preventDefault()

		#=======================================================================
		# Send a pixel-placement message

		ws_send_putPixel g_pos.xf, g_pos.yf, $('.palette .colors .color.selected')[0].dataset.index

		#=======================================================================
		# Update the UI

		# Show appropriate follow-up status
		if g_role is ADMN then status_set STATUS_PLACETILE
		if g_role is AUTH then status_set STATUS_COOLDOWN

		# Clean the palette UI
		palette_clearUI()

		false

