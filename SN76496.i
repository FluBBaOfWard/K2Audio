;@ ASM header for the SN76496 emulator
;@

	snptr			.req r12

							;@ SN76496.s
	.struct 0
	ch0Frq:			.short 0
	ch0Cnt:			.short 0
	ch1Frq:			.short 0
	ch1Cnt:			.short 0
	ch2Frq:			.short 0
	ch2Cnt:			.short 0
	ch3Frq:			.short 0
	ch3Cnt:			.short 0

	currentBits:	.long 0

	rng:			.long 0
	noiseFB:		.long 0

	snAttChg:		.byte 0
	snLastReg:		.byte 0
	snLastRegL:		.byte 0
	snPadding:		.space 1

	ch0Reg:			.short 0
	ch0Att:			.short 0
	ch1Reg:			.short 0
	ch1Att:			.short 0
	ch2Reg:			.short 0
	ch2Att:			.short 0
	ch3Reg:			.short 0
	ch3Att:			.short 0

	ch0RegL:		.short 0
	ch0AttL:		.short 0
	ch1RegL:		.short 0
	ch1AttL:		.short 0
	ch2RegL:		.short 0
	ch2AttL:		.short 0
	ch3RegL:		.short 0
	ch3AttL:		.short 0

	calculatedVolumes:	.space 16*2*2

	snSize:

;@----------------------------------------------------------------------------

