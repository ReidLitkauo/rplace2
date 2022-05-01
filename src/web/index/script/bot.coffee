################################################################################
# Bot handling

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Event handling

$ ->

	$('.panel.button.bot').on 'click', (e) ->

		# Create a new file selection element
		fsel = $("<input type='file' accept='image/png'>")

		# Simulate a click to open file select dialog
		fsel.click()

		# Set callback to run when user selects a file
		fsel.on 'change', (e) ->

			# If no file was selected
			if !e.target.files.length then alert 'no file' # TODO

			# Decode image
			userimg = UPNG.decode await e.target.files[0].arrayBuffer()

			console.log userimg

