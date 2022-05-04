################################################################################
# Helper functions

#///////////////////////////////////////////////////////////////////////////////
# Open chat

chat_open = ->

	$('.chat-parent').removeClass '-hidden'

#///////////////////////////////////////////////////////////////////////////////
# Close chat

chat_close = ->

	$('.chat-parent').addClass '-hidden'

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