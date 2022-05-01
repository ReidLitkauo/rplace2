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

	$('.panel.status').text window.lang['status_' + s]['en']

#///////////////////////////////////////////////////////////////////////////////
# Retrieve status

status_get = () ->
	$('.panel.status')[0].dataset.mode

#///////////////////////////////////////////////////////////////////////////////
# Show cooldown message to user

status_handleCooldown = (timeleft = RATELIMIT_SEC) ->

	intervalfn = () ->

		# Clear the interval if we don't need it anymore
		if timeleft <= 0
			$('.panel.status .timeleft').html ''
			window.clearTimeout interval
			status_set STATUS_PLACETILE
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

			when STATUS_LINKACCT
				window.open(document.location.protocol + "//" + document.location.host + "/endpoint/link-reddit-account", "_blank").focus()

			when STATUS_PLACETILE
				g_pos.set g_pos.xf + 0.5, g_pos.yf + 0.5, null
				canvas_applyPos()
				$('.palette').removeClass('hidden')

