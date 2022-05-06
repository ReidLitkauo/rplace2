################################################################################
# /src/web/index/script/constants.coffee
# Smattering of constants used everywhere
# Eventually these all should probably find another home...
# ought to clean out the junk drawer
# All constants must be kept the same as the ones used by the server

export default

	#///////////////////////////////////////////////////////////////////////////
	# Websocket message types

	# Server messages

	MSG_S_USERINFO:  0x10

	MSG_S_BOARD: 0x20

	MSG_S_UPDATE:    0x30

	MSG_S_COOLDOWN:  0x40

	MSG_S_CHAT:      0x50

	# Client messages

	MSG_C_PLACE:     0xA0
	MSG_C_IMAGE:     0xA1
	MSG_C_CHAT:      0xB0

	#///////////////////////////////////////////////////////////////////////////
	# User roles

	ROLE_ANON: 0x80
	ROLE_AUTH: 0x81
	ROLE_BANN: 0x82
	ROLE_ADMN: 0x83

	#///////////////////////////////////////////////////////////////////////////
	# Miscellany

	BOARD_WIDTH:  2000
	BOARD_HEIGHT: 2000

	RATELIMIT_SEC: 10

	############################################################################
	# Variables

	# In-memory representation of the board as palette indices
	board: null

	# User role
	role: 0x80 # ROLE_ANON

	# Cooldown left in seconds
	cooldown: null

