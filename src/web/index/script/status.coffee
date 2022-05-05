################################################################################
# Helper functions

#///////////////////////////////////////////////////////////////////////////////
# Set status

status_set = (s, timeleft = RATELIMIT_SEC) ->

	#===========================================================================
	# Common preprocessing

	# Set dataset attribute right away
	$('.panel.status')[0].dataset.mode = s

	#===========================================================================
	# Special considerations

	# Do we need to widen the status bar?
	if s == STATUS_LINKACCT || s == STATUS_BANNED
		$('.panel.status').addClass 'wide'
	else
		$('.panel.status').removeClass 'wide'
	
	# Special handling for cooldown status
	if s == STATUS_COOLDOWN
		$('.panel.status').html "
			<img class='timeleft' src='/timer.svg' />
			<div class='timeleft'></div>
			"
		status_handleCooldown timeleft
		return

	#===========================================================================
	# Show status to user

	# TODO allow for multiple languages
	$('.panel.status').text g_text.status[s]['en']

#///////////////////////////////////////////////////////////////////////////////
# Retrieve status

status_get = ->
	$('.panel.status')[0].dataset.mode

#///////////////////////////////////////////////////////////////////////////////
# Show cooldown message to user

status_handleCooldown = (cooldown = RATELIMIT_SEC) ->

	g_cooldown = cooldown

	intervalfn = () ->

		# No point in continuing if status has changed since last update
		if status_get() isnt STATUS_COOLDOWN
			clearTimeout interval
			return

		# Clear the interval if we don't need it anymore
		if g_cooldown <= 0
			g_cooldown = null
			$('.panel.status .timeleft').html ''
			clearTimeout interval
			status_set STATUS_PLACETILE
			return
		
		# Determine hours/minutes/seconds left
		h = Math.floor(g_cooldown / 3600)
		m = Math.floor((g_cooldown % 3600) / 60)
		s = Math.floor(g_cooldown % 60)

		# Add padding zeroes if needed
		hs = (if h < 10 then "0" else "") + h
		ms = (if m < 10 then "0" else "") + m
		ss = (if s < 10 then "0" else "") + s
		
		# Display the properly-formatted time left
		$('.panel.status .timeleft').html "#{hs}:#{ms}:#{ss}"

		# Decrement our time left
		g_cooldown--
	
	# Set the interval
	interval = setInterval intervalfn, 1000
	intervalfn()

################################################################################
# Initialization

$ ->

	# Set initial status
	status_set STATUS_LOADING

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Clicked on status bar: Do whatever is most appropriate

	$('.panel.status').on 'click', (e) ->
		
		switch status_get()

			#when STATUS_LOADING

			#===================================================================
			# Link account: Start reddit account linkage webflow

			when STATUS_LINKACCT
				window.open(document.location.protocol + "//" + document.location.host + "/endpoint/link-reddit-account", "_blank").focus()

			#===================================================================
			# Place tile: Show the palette

			when STATUS_PLACETILE
				g_pos.set g_pos.xf + 0.5, g_pos.yf + 0.5, null
				$('.palette').removeClass('-hidden')

			#===================================================================
			# Bot positioning: Place the image

			when STATUS_BOTPOS

				# Start the bot normally if we're a normal user
				if g_role is ROLE_AUTH then bot_start()

				# Admins get access to insta-place
				if g_role is ROLE_ADMN then bot_place()


			#===================================================================
			# Bot running: Stop the bot

			when STATUS_BOTRUN
				bot_cancel()

