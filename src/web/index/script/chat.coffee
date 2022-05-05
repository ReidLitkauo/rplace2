################################################################################
# Helper functions

#///////////////////////////////////////////////////////////////////////////////
# Open chat

chat_open = ->

	# Reveal the chat side panel
	$('.chat-parent').removeClass '-hidden'

	# Focus the chat input
	$('.chat-parent .chat-send input').focus()

#///////////////////////////////////////////////////////////////////////////////
# Close chat

chat_close = ->

	$('.chat-parent').addClass '-hidden'

#///////////////////////////////////////////////////////////////////////////////
# Receive chat messages

chat_receiveMessages = (raw) ->

	#===========================================================================
	# Extract chats from raw

	# Did a lot of fiddling in the JS console to get this juuuuust right
	# - Make a typed array out of the buffer behind the message
	# - Chop off the first byte and run the rest through a UTF8 decoder
	# - Parse the resulting text into a JS object
	msgs = JSON.parse new TextDecoder().decode new Uint8Array(raw.buffer).slice 1

	# We now have an array of messages to append,
	# with the oldest at index 0 and newest at the end.

	#===========================================================================
	# Store scroll position

	# Store a reference to the chat log for convenience/speed
	chatlog = $('.chat-log')[0]

	# Determine if we're scrolled to the bottom
	# https://stackoverflow.com/a/876134
	scroll_lock = chatlog.scrollTop is (chatlog.scrollHeight - chatlog.offsetHeight)

	#===========================================================================
	# Append messages to the chat log

	# Cycle through each message
	for m in msgs

		# If this message already exists in the chat log, skip it
		if $(".chat-log .msg[id=#{m.id}]").length then continue

		# If this message's author also wrote the most recent message present,
		# then append to the last message group
		if $('.chat-log .msg-group:last-child .user').text() is m.user
			$('.chat-log .msg-group:last-child').append($("
				<div class='msg'>#{m.msg}</div>
			"))

		# Otherwise, create a new group with the message
		else $('.chat-log').append($("
			<div class='msg-group'>
				<div class='user'>#{m.user}</div>
				<div class='msg'>#{m.msg}</div>
			</div>
		"))
	
	#===========================================================================
	# Keep scroll lock if already set

	if scroll_lock
		chatlog.scrollTop = chatlog.scrollHeight - chatlog.offsetHeight

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Send a message

	$('.chat-parent form.chat-send').on 'submit', (e) ->

		e.preventDefault()

		ws_send_chat $('.chat-parent form.chat-send input').val()

		$('.chat-parent form.chat-send input').val('')

		false

	#///////////////////////////////////////////////////////////////////////////
	# Open and close

	$('.panel.button.chat').on 'click', (e) ->
		chat_open()
	
	$('.chat-parent button.cancel').on 'click', (e) ->
		chat_close()