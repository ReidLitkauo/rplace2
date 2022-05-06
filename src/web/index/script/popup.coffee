################################################################################
# /src/web/index/script/popup.coffee
# Handles everything related to popups that get in your FACE

jsdom = require('jsdom')
$ = if window? then require('jquery') else require('jquery')(new jsdom.JSDOM().window)

import Text from './text.coffee'

################################################################################
# Exported variables

# Popup types
export ABOUT    = 'about'
export VALIDATE = 'validate'

################################################################################
# Private variables

################################################################################
# Exported functions

#///////////////////////////////////////////////////////////////////////////////
# Open a popup

export open = (popup, extra = null) ->

	#===========================================================================
	# Special handling: Validation popup
	# Show the relevant account validation message to the user

	if popup is VALIDATE

		# The validate message type to grab is stored in the extra parameter

		# Make sure we have a valid validate message
		# If not, then do nothing
		if not extra? or extra not of Text.validate
			return
		
		# If we do, then show the text of that message
		# TODO make language-independent
		$('.popup.validate .text').html Text.validate[extra]['en']

	#===========================================================================
	# General post-processing

	# Close all open popups, only have one open at a time
	close()

	# Show the requested popup
	$(".popup.#{popup}, .popup-grayout").removeClass '-hidden'

#///////////////////////////////////////////////////////////////////////////////
# Close all popups

close = -> $('.popup, .popup-grayout').addClass '-hidden'

################################################################################
# Private functions

################################################################################
# Initialization

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Show account validation popup if needed

	# Parser for the URL's query string
	query = new URLSearchParams window.location.search

	# Check if we have a validation message to show to the user
	if (validate_msg = query.get 'validate')?
		open VALIDATE, validate_msg

################################################################################
# Event handling

$ ->

	#///////////////////////////////////////////////////////////////////////////
	# Open popups

	#===========================================================================
	# About popup

	$('.panel.button.about').on 'click', (e) ->

		open ABOUT
    
	#///////////////////////////////////////////////////////////////////////////
	# Close popups

	$('body').on 'click', (e) ->

		# Close popups when user clicks outside of them
		if $(e.target).add($(e.target).parents()).is('.popup-grayout')
			return close()

		# Close popups when user clicks on a cancel button
		if $(e.target).add($(e.target).parents()).is('button.cancel')
			return close()

