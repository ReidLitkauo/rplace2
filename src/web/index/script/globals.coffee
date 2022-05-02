################################################################################
# Constants
# Must be kept the same as the ones used by the server

#///////////////////////////////////////////////////////////////////////////////
# Websocket message types

# Server messages

MSG_S_BOARDANON = 0x20
MSG_S_BOARDAUTH = 0x21
MSG_S_BOARDBANN = 0x22
MSG_S_BOARDADMN = 0x23

MSG_S_UPDATE    = 0x30

MSG_S_COOLDOWN  = 0x40

# Client messages

MSG_C_PLACE     = 0xA0
MSG_C_IMAGE     = 0xA1

#///////////////////////////////////////////////////////////////////////////////
# User roles

ANON = 0x80
AUTH = 0x81
BANN = 0x82
ADMN = 0x83

#///////////////////////////////////////////////////////////////////////////////
# Statuses

STATUS_LOADING   = 'loading'
STATUS_LINKACCT  = 'linkacct'
STATUS_PLACETILE = 'placetile'
STATUS_CONNERR   = 'connerr'
STATUS_DCONN     = 'dconn'
STATUS_COOLDOWN  = 'cooldown'
STATUS_BANNED    = 'banned'
STATUS_BOTPOS    = 'botpos'
STATUS_BOTRUN    = 'botrun'

#///////////////////////////////////////////////////////////////////////////////
# Color palette

PALETTE = [
	[0x6D, 0x00, 0x1A, 0xFF],
	[0xBE, 0x00, 0x39, 0xFF],
	[0xFF, 0x45, 0x00, 0xFF],
	[0xFF, 0xA8, 0x00, 0xFF],
	[0xFF, 0xD6, 0x35, 0xFF],
	[0xFF, 0xF8, 0xB8, 0xFF],
	[0x00, 0xA3, 0x68, 0xFF],
	[0x00, 0xCC, 0x78, 0xFF],
	[0x7E, 0xED, 0x56, 0xFF],
	[0x00, 0x75, 0x6F, 0xFF],
	[0x00, 0x9E, 0xAA, 0xFF],
	[0x00, 0xCC, 0xC0, 0xFF],
	[0x24, 0x50, 0xA4, 0xFF],
	[0x36, 0x90, 0xEA, 0xFF],
	[0x51, 0xE9, 0xF4, 0xFF],
	[0x49, 0x3A, 0xC1, 0xFF],
	[0x6A, 0x5C, 0xFF, 0xFF],
	[0x94, 0xB3, 0xFF, 0xFF],
	[0x81, 0x1E, 0x9F, 0xFF],
	[0xB4, 0x4A, 0xC0, 0xFF],
	[0xE4, 0xAB, 0xFF, 0xFF],
	[0xDE, 0x10, 0x7F, 0xFF],
	[0xFF, 0x38, 0x81, 0xFF],
	[0xFF, 0x99, 0xAA, 0xFF],
	[0x6D, 0x48, 0x2F, 0xFF],
	[0x9C, 0x69, 0x26, 0xFF],
	[0xFF, 0xB4, 0x70, 0xFF],
	[0x00, 0x00, 0x00, 0xFF],
	[0x51, 0x52, 0x52, 0xFF],
	[0x89, 0x8D, 0x90, 0xFF],
	[0xD4, 0xD7, 0xD9, 0xFF],
	[0xFF, 0xFF, 0xFF, 0xFF],
]

# Palette as uint32's
# Generate from PALETTE
PALETTE_INTS = new Uint32Array PALETTE.length
for i in [0 ... PALETTE.length] then PALETTE_INTS[i] = PALETTE[i][0] << 24 | PALETTE[i][1] << 16 | PALETTE[i][2] << 8 | PALETTE[i][3] << 0

#///////////////////////////////////////////////////////////////////////////////
# Miscellany

BOARD_WIDTH = BOARD_HEIGHT = 2000

RATELIMIT_SEC = 10

################################################################################
# Variables

# In-memory representation of the board as palette indices
g_board = new Uint8ClampedArray(BOARD_WIDTH * BOARD_HEIGHT)

# Canvas positioning
# To be handled by the position file
g_pos = null

# User role
g_role = ANON

# Cooldown left in seconds
g_cooldown = null