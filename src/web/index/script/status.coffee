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
				g_pos.set g_pos.xf + 0.5, g_pos.yf + 0.5, null
				render_applyPos()
				$('.palette').removeClass('hidden')

