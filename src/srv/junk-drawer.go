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

func PackPixel3 (x uint16, y uint16, c byte) (uint32) {
	return PackPixel2( ((uint32)(x)) + (((uint32)(y)) * ((uint32)(g_cfg.Board.Width))), c )
}

func UnpackPixel2 (p uint32) (uint32, byte) {
	return ((p >> 8) & 0xFFFFFF), (byte)((p >> 0) & 0xFF)
}

func UnpackPixel3 (p uint32) (uint16, uint16, byte) {
	i, c := UnpackPixel2(p)
	return (uint16)(i % ((uint32)(g_cfg.Board.Width))), (uint16)(i / ((uint32)(g_cfg.Board.Width))), c
}
