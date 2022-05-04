################################################################################
# Helper Functions

#///////////////////////////////////////////////////////////////////////////////
# Open a popup

popup_open = (popup, extra = null) ->

	#===========================================================================
	# Special handling: Validation popup
	# Show the relevant account validation message to the user

	if popup is "validate"

		# The validate message type to grab is stored in the extra parameter

		# Make sure we have a valid validate message
		# If not, then do nothing
		if not extra? or extra not of g_text.validate
			return
		
		# If we do, then show the text of that message
		# TODO make language-independent
		$('.popup.validate .text').html g_text.validate[extra]['en']

	#===========================================================================
	# General post-processing

	# Close all open popups, only have one open at a time
	popup_close()

	# Show the requested popup
	$(".popup.#{popup}, .popup-grayout").removeClass '-hidden'

#///////////////////////////////////////////////////////////////////////////////
# Close all popups

popup_close = ->

	# Hide all popups and the grayout backdrop
	$('.popup, .popup-grayout').addClass '-hidden'

################################################################################
# Initialization

$ ->

	# Parser for the URL's query string
	query = new URLSearchParams window.location.search

	# Check if we have a validation message to show to the user
	if (validate_msg = query.get 'validate')?
		popup_open 'validate', validate_msg

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Open popups

	#===========================================================================
	# About popup

	$('.panel.button.about').on 'click', (e) ->

		popup_open 'about'
    
	#///////////////////////////////////////////////////////////////////////////
	# Close popups

	# TODO add close buttons
	$('body').on 'click', (e) ->

		# Close popups when user clicks outside of them
		if $(e.target).add($(e.target).parents()).is('.popup-grayout')
			return popup_close()

		# Close popups when user clicks on a cancel button
		if $(e.target).add($(e.target).parents()).is('button.cancel')
			return popup_close()

