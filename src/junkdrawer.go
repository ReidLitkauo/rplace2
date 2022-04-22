package main

import (
)

////////////////////////////////////////////////////////////////////////////////
// Pixel packing/unpacking

// Packed pixels are the size of a uint32 and are formatted like this:
// index (x + (y * WIDTH)) (24 bits) | color-code (8 bits)
// 2-version converts x and y into a single index
// 3-version separates them out

func PackPixel2 (i uint32, c byte) (uint32) {
	return ((i & 0xFFFFFF) << 8) | (((uint32)(c) & 0xFF) << 0)
}

func PackPixel3 (x uint32, y uint32, c byte) (uint32) {
	return PackPixel2( x + (y * BOARD_WIDTH), c )
}

func UnpackPixel2 (p uint32) (uint32, byte) {
	return ((p >> 8) & 0xFFFFFF), (byte)((p >> 0) & 0xFF)
}

func UnpackPixel3 (p uint32) (uint32, uint32, byte) {
	i, c := UnpackPixel2(p)
	return i % BOARD_WIDTH, i / BOARD_WIDTH, c
}
