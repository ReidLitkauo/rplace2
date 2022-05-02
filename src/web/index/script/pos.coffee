################################################################################
# Position declaration

g_pos = {

	#///////////////////////////////////////////////////////////////////////////
	# Position variables

	# X/Y coords of screen center
	x: null
	y: null

	# Floored versions of coords
	xf: null
	yf: null

	# Coordinate constraints
	# min <= x/y < max
	xmin: 0
	ymin: 0
	xmax: BOARD_WIDTH
	ymax: BOARD_HEIGHT

	# Zoom index and zoom level
	zi: null
	zl: null

	# Valid values for zoom level
	zooms: [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 3, 5, 10]

	#///////////////////////////////////////////////////////////////////////////
	# Position manipulation

	set: (x, y, zi) ->

		# Check for null values, which indicate to not change that coord
		x ?= this.x
		y ?= this.y
		zi ?= this.zi

		# Range checks and other validation
		if x <  this.xmin then x = this.xmin
		if y <  this.ymin then y = this.ymin
		if x >= this.xmax then x = this.xmax * (1 - Number.EPSILON)
		if y >= this.ymax then y = this.ymax * (1 - Number.EPSILON)
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

		# Update view with new coords
		canvas_applyPos()

		# For chaining, I guess
		this

	add: (x, y, zi) -> this.set(x + this.x, y + this.y, zi + this.zi)

	#///////////////////////////////////////////////////////////////////////////
	# Position constraints

	setMin: (x = 0, y = 0) ->

		# Perform min adjustment
		this.xmin = x
		this.ymin = y

		# Reposition if necessary
		this.set this.x, this.y, this.zi
	
	setMax: (x = BOARD_WIDTH, y = BOARD_HEIGHT) ->

		# Perform max adjustment
		this.xmax = x
		this.ymax = y

		# Reposition if necessary
		this.set this.x, this.y, this.zi

}

################################################################################
# Initialization

$ ->

	# Grab position data from cookie, set to defaults if needed
	x  = $.cookie('posx')  ? 1000.5
	y  = $.cookie('posy')  ? 1000.5
	zi = $.cookie('poszi') ? 6

	# Initialize position
	g_pos.set x, y, zi

