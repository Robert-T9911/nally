/*
 *  CommonType.h
 *  MacBlueTelnet
 *
 *  Created by Yung-Luen Lan on 9/11/07.
 *  Copyright 2007 yllan.org. All rights reserved.
 *
 */

typedef union {
	unsigned short v;
	struct {
		unsigned int fgColor	: 4;
		unsigned int bgColor	: 4;
		unsigned int bold		: 1;
		unsigned int underline	: 1;
		unsigned int blink		: 1;
		unsigned int reverse	: 1;
		unsigned int doubleByte	: 2;
		unsigned int nothing	: 2;
	} f;
} attribute;

typedef struct {
	unsigned char byte;
	attribute attr;
} cell;

typedef enum {C0, INTERMEDIATE, ALPHABETIC, DELETE, C1, G1, SPECIAL, ERROR} ASCII_CODE;
