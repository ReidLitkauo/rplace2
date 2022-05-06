################################################################################
# /src/web/index/script/pos.coffee
# Abstract representation of the user's position on the canvas

jsdom = require('jsdom')
$ = if window? then require('jquery') else require('jquery')(new jsdom.JSDOM().window)

import Globals from './globals.coffee'

import * as Ui from './ui.coffee'

################################################################################
# Exported variables

################################################################################
# Private variables

#///////////////////////////////////////////////////////////////////////////////
# 2d positioning

# X/Y coords of screen center
# Range: min <= coord < max
# Coords are floats
l_x = null
l_y = null

# Floored versions of above coords
l_xf = null
l_yf = null

# Coordinate constraints
l_xmin = 0
l_ymin = 0
l_xmax = Globals.BOARD_WIDTH
l_ymax = Globals.BOARD_HEIGHT

#///////////////////////////////////////////////////////////////////////////////
# Zoom

# List of allowable zooms
l_zooms = [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 3, 5, 10]

# Zoom level, expressed in UI as a multiplier
l_zl = null

# Zoom index, current index of above zoom level in list of allowable zooms
l_zi = null

################################################################################
# Exported functions

#///////////////////////////////////////////////////////////////////////////////
# Set user position to specified value
# Ignores all parameters set to null

export set = (x, y, zi) ->
	
	#===========================================================================
	# Validation and range checks
	
	#---------------------------------------------------------------------------
	# Detect null parameters

	# Check for null values, which indicate to not change that coord
	x  ?= l_x
	y  ?= l_y
	zi ?= l_zi

	#---------------------------------------------------------------------------
	# 2d pos: Range checks

	# Check lower bound of range
	if x < l_xmin then x = l_xmin
	if y < l_ymin then y = l_ymin

	# Upper bound or range
	# Use Number.EPSILON here to make the number always below the max
	# The way in which it's used here avoids rounding errors from large floats
	if x >= l_xmax then x = l_xmax * (1 - Number.EPSILON)
	if y >= l_ymax then y = l_ymax * (1 - Number.EPSILON)

	#---------------------------------------------------------------------------
	# Zoom: Validation and range checks

	# Force zoom index to be integer
	zi = Math.floor zi

	# Range checks, keep within allowable zooms
	if zi <  0              then zi = 0
	if zi >= l_zooms.length then zi = l_zooms.length - 1

	#===========================================================================
	# Set values
	
	l_x = x
	l_y = y

	l_xf = Math.floor x
	l_yf = Math.floor y

	l_zi = zi
	l_zl = l_zooms[zi]
	
	#===========================================================================
	# Cleanup

	# Update the UI
	Ui.applyPos val()

	# For method chaining
	this

#///////////////////////////////////////////////////////////////////////////////
# Add values to current values

export add = (x, y, zi) -> set x + l_x, y + l_y, zi + l_zi

#///////////////////////////////////////////////////////////////////////////////
# Set position constraints

#===========================================================================
# Minimum

export min = (x = 0, y = 0) ->

	# Adjust bounds
	l_xmin = x
	l_ymin = y

	# Reposition if necessary
	set l_x, l_y, l_zi

#===========================================================================
# Maximum

export max = (x = Globals.BOARD_WIDTH, y = Globals.BOARD_HEIGHT) ->

	# Adjust bounds
	l_xmax = x
	l_ymax = y

	# Reposition if necessary
	set l_x, l_y, l_zi

#///////////////////////////////////////////////////////////////////////////////
# Retrieve current values

export val = ->
	x: l_x
	y: l_y
	xf: l_xf
	yf: l_yf
	zi: l_zi
	zl: l_zl

################################################################################
# Initialization

