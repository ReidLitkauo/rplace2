################################################################################
# /src/web/index/script/chat.coffee
# Handles all the chat stuff

import $ from 'jquery'

import * as Ws from './ws.coffee'

################################################################################
# Exported variables

################################################################################
# Private variables

################################################################################
# Exported functions

#///////////////////////////////////////////////////////////////////////////////
# Open the chat sidebar

export open = ->

	# Reveal the chat sidebar
	$('.chat-parent').removeClass '-hidden'

	# Focus the chat input
	$('.chat-parent .chat-send input').focus()

#///////////////////////////////////////////////////////////////////////////////
# Close the chat sidebar

export close = ->

	# Hide the chat sidebar
	$('.chat-parent').addClass '-hidden'

	# Blur the chat input
	# Let's not accidentally type into it when using keyboard shortcuts
	$('.chat-parent .chat-send input').blur()

#///////////////////////////////////////////////////////////////////////////////
# Display messages received from the server
# This function expects Ws to have already done the heavy lifting of extracting
# the JSON from the raw message

export displayMessages = (msgs) ->

	#===========================================================================
	# Store scroll position

	# Store a reference to the chat log for convenience/speed
	chatlog = $('.chat-log')[0]

	# Determine if we're scrolled to the bottom
	# https://stackoverflow.com/a/876134
	# Also activate if we're close enough (within 3px)
	scroll_lock = (chatlog.scrollTop >= chatlog.scrollHeight - chatlog.offsetHeight - 3)

	#===========================================================================
	# Append messages to the chat log

	# Cycle through each message
	for m in msgs

		#-----------------------------------------------------------------------
		# Initialization

		# If this message already exists in the chat log, skip it
		if $(".chat-log .msg[id=#{m.id}]").length then continue

		#-----------------------------------------------------------------------
		# Add to existing group

		# If this message's author also wrote the most recent message present,
		# then append to the last message group
		if $('.chat-log .msg-group:last-child .user').text() is m.user

			# Create a new element for the message
			el_msg = $('<div class="msg">')

			# Sanitize user input through the text method
			el_msg.text m.msg

			# Display in the chat log
			$('.chat-log .msg-group:last-child').append el_msg

		#-----------------------------------------------------------------------
		# Create a new group

		# If the author of the most recent group is anyone else
		else

			# Create new elements for the message
			el_user  = $('<div class="user">')
			el_msg   = $('<div class="msg">')
			el_group = $('<div class="msg-group">')

			# Fill appropriately
			el_user.text m.user
			el_msg.text  m.msg

			# Create tree and append to chat log
			el_group.append el_user
			el_group.append el_msg
			$('.chat-log').append el_group
	
	#===========================================================================
	# Keep scroll lock if already set

	if scroll_lock
		chatlog.scrollTop = chatlog.scrollHeight - chatlog.offsetHeight

################################################################################
# Private functions

################################################################################
# Initialization

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Send a message

	$('.chat-parent form.chat-send').on 'submit', (e) ->

		e.preventDefault()

		Ws.sendChat $('.chat-parent form.chat-send input').val()

		$('.chat-parent form.chat-send input').val('')

		false

	#///////////////////////////////////////////////////////////////////////////
	# Open and close

	$('.panel.button.chat').on 'click', (e) ->
		open()
	
	$('.chat-parent button.cancel').on 'click', (e) ->
		close()

