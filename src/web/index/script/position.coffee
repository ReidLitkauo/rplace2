################################################################################
# Canvas positioning

window.g_pos = {

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# Position variables

	# X/Y coords of screen center
	x: null
	y: null

	# Floored versions of coords
	xf: null
	yf: null

	# Zoom index and zoom level
	zi: null
	zl: null

	# Valid values for zoom level
	zooms: [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 3, 5, 10]

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# Set position
	set: (x, y, zi) ->

		# Check for null values, which indicate to not change that coord
		x ?= this.x
		y ?= this.y
		zi ?= this.zi

		# Range checks and other validation
		if x < 0 then x = 0
		if y < 0 then y = 0
		if x >= BOARD_WIDTH  then x = BOARD_WIDTH  * (1 - Number.EPSILON)
		if y >= BOARD_HEIGHT then y = BOARD_HEIGHT * (1 - Number.EPSILON)
		zi = Math.floor zi
		if zi < 0 then zi = 0
		if zi >= this.zooms.length then zi = this.zooms.length - 1
		
		# Set values
		this.x = x
		this.y = y
		this.xf = Math.floor x
		this.yf = Math.floor y
		this.zi = zi
		this.zl = this.zooms[zi]

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# Add position
	add: (x, y, zi) -> this.set(x + this.x, y + this.y, zi + this.zi)

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Initialization

$ ->

	# Grab position data from cookie, set to defaults if needed
	x = $.cookie('posx')
	x ?= 1000.5
	y = $.cookie('posy')
	y ?= 1000.5
	zi = $.cookie('poszi')
	zi ?= 6

	# Initialize position
	g_pos.set x, y, zi

