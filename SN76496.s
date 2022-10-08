;@ SNK Neogeo Pocket K2Audio sound chip emulator for ARM32.
#ifdef __arm__

#include "SN76496.i"

	.global sn76496Reset
	.global sn76496SaveState
	.global sn76496LoadState
	.global sn76496GetStateSize
	.global sn76496Mixer
	.global sn76496W
	.global sn76496L_W
								;@ These values are for the SMS/GG/MD vdp/sound chip.
.equ PFEED_SMS,	0x8000			;@ Periodic Noise Feedback
.equ WFEED_SMS,	0x9000			;@ White Noise Feedback

	.syntax unified
	.arm

#ifdef NDS
	.section .itcm						;@ For the NDS
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#else
	.section .text
#endif
	.align 2
;@----------------------------------------------------------------------------
;@ r0 = mix length.
;@ r1 = mixerbuffer.
;@ r2 = snptr.
;@ r3 -> r6 = pos+freq.
;@ r7  = currentBits.
;@ r8  = noise generator.
;@ r9  = noise feedback.
;@ r10  = mixer reg.
;@----------------------------------------------------------------------------
sn76496Mixer:				;@ In r0=len, r1=dest, r2=snptr
	.type   sn76496Mixer STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r10,lr}
	ldmia r2,{r3-r9,lr}		;@ Load freq/addr0-3, currentBits, rng, noisefb, attChg
	tst lr,#0xff
	blne calculateVolumes
;@----------------------------------------------------------------------------
mixLoop:
	mov r10,#0x80000000
innerMixLoop:
	adds r3,r3,#0x00400000
	subcs r3,r3,r3,lsl#16
	eorcs r7,r7,#0x04

	adds r4,r4,#0x00400000
	subcs r4,r4,r4,lsl#16
	eorcs r7,r7,#0x08

	adds r5,r5,#0x00400000
	subcs r5,r5,r5,lsl#16
	eorcs r7,r7,#0x10

	adds r6,r6,#0x00400000		;@ 0x00200000?
	subcs r6,r6,r6,lsl#16
	biccs r7,r7,#0x20
	movscs r8,r8,lsr#1
	eorcs r8,r8,r9
	orrcs r7,r7,#0x20

	ldr lr,[r2,r7]
	add r10,r10,lr
	sub r0,r0,#1
	tst r0,#3
	bne innerMixLoop
	eor r10,r10,#0x00008000
	cmp r0,#0
	strpl r10,[r1],#4
	bhi mixLoop

	stmia r2,{r3-r8}			;@ Writeback freq,addr,currentBits,rng
	ldmfd sp!,{r4-r10,lr}
	bx lr
;@----------------------------------------------------------------------------

	.section .text
	.align 2

;@----------------------------------------------------------------------------
sn76496Reset:				;@ In r0 = pointer to struct
	.type   sn76496Reset STT_FUNC
;@----------------------------------------------------------------------------
	mov r1,#0
	mov r2,#snSize/4			;@ 60/4=15
rLoop:
	subs r2,r2,#1
	strpl r1,[r0,r2,lsl#2]
	bhi rLoop

	ldr r2,=(WFEED_SMS<<16)+PFEED_SMS
	strh r2,[r0,#noiseFB]
	mov r2,#calculatedVolumes
	str r2,[r0,#currentBits]	;@ Add offset to calculatedVolumes
	str r1,[r0,r2]

	bx lr

;@----------------------------------------------------------------------------
sn76496SaveState:			;@ In r0=destination, r1=snptr. Out r0=state size.
	.type   sn76496SaveState STT_FUNC
;@----------------------------------------------------------------------------
	mov r2,#snStateEnd-snStateStart
	stmfd sp!,{r2,lr}

	bl memcpy

	ldmfd sp!,{r0,lr}
	bx lr
;@----------------------------------------------------------------------------
sn76496LoadState:			;@ In r0=snptr, r1=source. Out r0=state size.
	.type   sn76496LoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,lr}

	mov r2,#snStateEnd-snStateStart
	bl memcpy
	ldmfd sp!,{r0,lr}
	mov r1,#1
	strb r1,[r0,#snAttChg]

;@----------------------------------------------------------------------------
sn76496GetStateSize:		;@ Out r0=state size.
	.type   sn76496GetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	mov r0,#snStateEnd-snStateStart
	bx lr

;@----------------------------------------------------------------------------
sn76496W:					;@ In r0 = value, r1 = struct-pointer
	.type   sn76496W STT_FUNC
;@----------------------------------------------------------------------------
	tst r0,#0x80
	andne r3,r0,#0x70
	strbne r3,[r1,#snLastReg]
	ldrbeq r3,[r1,#snLastReg]
	movs r3,r3,lsr#5
	add r2,r1,r3,lsl#2
	bcc setFreq
doVolume:
	and r0,r0,#0x0F
	ldrb r3,[r2,#ch0Att]
	eors r3,r3,r0
	strbne r0,[r2,#ch0Att]
	strbne r3,[r1,#snAttChg]
	bx lr

setFreq:
	cmp r3,#2
	bhi setNoiseFreq
	bxmi lr
	tst r0,#0x80
	andeq r0,r0,#0x3F
	movne r0,r0,lsl#4
	strbeq r0,[r2,#ch0Reg+1]
	strbne r0,[r2,#ch0Reg]
	ldrh r0,[r2,#ch0Reg]
	movs r0,r0,lsl#2
	cmp r0,#0x0180				;@ We set any value under 6 to 1 to fix aliasing.
	movmi r0,#0x0040			;@ Value zero is same as 1 on SMS.
	strh r0,[r1,#ch1Reg]

	cmp r3,#2					;@ Ch2
	ldrbeq r2,[r1,#ch3Reg]
	cmpeq r2,#3
	strheq r0,[r1,#ch3Frq]
	bx lr

setNoiseFreq:
	and r2,r0,#3
	strb r2,[r1,#ch3Reg]
	tst r0,#4
	mov r0,#PFEED_SMS			;@ Periodic noise
	strh r0,[r1,#rng]
	movne r0,#WFEED_SMS			;@ White noise
	strh r0,[r1,#noiseFB]
	mov r3,#0x0400				;@ These values sound ok
	mov r3,r3,lsl r2
	cmp r2,#3
	ldrheq r3,[r1,#ch1Reg]
	strh r3,[r1,#ch3Frq]
	bx lr

;@----------------------------------------------------------------------------
sn76496L_W:					;@ In r0 = value, r1 = struct-pointer
	.type   sn76496L_W STT_FUNC
;@----------------------------------------------------------------------------
	tst r0,#0x80
	andne r3,r0,#0x70
	strbne r3,[r1,#snLastRegL]
	ldrbeq r3,[r1,#snLastRegL]
	movs r3,r3,lsr#5
	add r2,r1,r3,lsl#2
	bcc setFreqL
doVolumeL:
	and r0,r0,#0x0F
	ldrb r3,[r2,#ch0AttL]
	eors r3,r3,r0
	strbne r0,[r2,#ch0AttL]
	strbne r3,[r1,#snAttChg]
	bx lr

setFreqL:
	cmp r3,#3					;@ Noise channel
	bxeq lr
	tst r0,#0x80
	andeq r0,r0,#0x3F
	movne r0,r0,lsl#4
	strbeq r0,[r2,#ch0RegL+1]
	strbne r0,[r2,#ch0RegL]
	ldrh r0,[r2,#ch0RegL]
	movs r0,r0,lsl#2
	cmp r0,#0x0180				;@ We set any value under 6 to 1 to fix aliasing.
	movmi r0,#0x0040			;@ Value zero is same as 1 on SMS.
	strh r0,[r2,#ch0Frq]

//	cmp r3,#2					;@ Ch2
//	ldrbeq r2,[r1,#ch3Reg]
//	cmpeq r2,#3
//	strheq r0,[r1,#ch3Frq]
	bx lr

;@----------------------------------------------------------------------------
calculateVolumes:			;@ In r2 = snptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r1,r3-r7}

	adr r1,attenuation1_4

	ldrb r0,[r2,#ch0Att]
	ldr r3,[r1,r0,lsl#2]
	ldrb r0,[r2,#ch0AttL]
	ldr r0,[r1,r0,lsl#2]
	orr r3,r3,r0,lsl#16

	ldrb r0,[r2,#ch1Att]
	ldr r4,[r1,r0,lsl#2]
	ldrb r0,[r2,#ch1AttL]
	ldr r0,[r1,r0,lsl#2]
	orr r4,r4,r0,lsl#16

	ldrb r0,[r2,#ch2Att]
	ldr r5,[r1,r0,lsl#2]
	ldrb r0,[r2,#ch2AttL]
	ldr r0,[r1,r0,lsl#2]
	orr r5,r5,r0,lsl#16

	ldrb r0,[r2,#ch3Att]
	ldr r6,[r1,r0,lsl#2]
	ldrb r0,[r2,#ch3AttL]
	ldr r0,[r1,r0,lsl#2]
	orr r6,r6,r0,lsl#16

	add r7,r2,#calculatedVolumes
	mov r1,#15
volLoop:
	ands r0,r1,#0x01
	movne r0,r3
	tst r1,#0x02
	addne r0,r0,r4
	tst r1,#0x04
	addne r0,r0,r5
	tst r1,#0x08
	addne r0,r0,r6
	str r0,[r7,r1,lsl#2]
	subs r1,r1,#1
	bne volLoop
	strb r1,[r2,#snAttChg]
	ldmfd sp!,{r0,r1,r3-r7}
	bx lr
;@----------------------------------------------------------------------------
attenuation:						;@ each step * 0.79370053 (-2dB?)
	.long 0x3FFF3FFF,0x32CB32CB,0x28512851,0x20002000,0x19661966,0x14281428,0x10001000,0x0CB30CB3
	.long 0x0A140A14,0x08000800,0x06590659,0x050A050A,0x04000400,0x032C032C,0x02850285,0x00000000
attenuation1_4:						;@ each step * 0.79370053 (-2dB?)
	.long 0x0FFF,0x0CB3,0x0A14,0x0800,0x0659,0x050A,0x0400,0x032C
	.long 0x0285,0x0200,0x0196,0x0143,0x0100,0x00CB,0x00A1,0x0000
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
