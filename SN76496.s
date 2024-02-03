;@
;@  SN76496.s
;@  K2Audio
;@
;@  Created by Fredrik Ahlström on 2008-04-02.
;@  Copyright © 2008-2024 Fredrik Ahlström. All rights reserved.
;@
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
	.equ PFEED_SMS,	0x8000		;@ Periodic Noise Feedback
	.equ WFEED_SMS,	0x9000		;@ White Noise Feedback

#if !defined(SN_UPSHIFT)
	#define SN_UPSHIFT (2)
#endif
#define SN_ADDITION 0x00400000

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
;@ r0  = Mix length.
;@ r1  = Mixerbuffer.
;@ r2  = snptr.
;@ r3 -> r6 = pos+freq.
;@ r7  = CurrentBits.
;@ r8  = Noise generator.
;@ r9  = Noise feedback.
;@ r12 = Scrap.
;@ lr  = Mixer reg.
;@----------------------------------------------------------------------------
sn76496Mixer:				;@ In r0=len, r1=dest, r2=snptr
	.type   sn76496Mixer STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r9,lr}
	ldmia r2,{r3-r9,lr}		;@ Load freq/addr0-3, currentBits, rng, noisefb, attChg
	mov r0,r0,lsl#SN_UPSHIFT
	tst lr,#0xff
	blne calculateVolumes
;@----------------------------------------------------------------------------
mixLoop:
	mov lr,#0x80000000
innerMixLoop:
	adds r3,r3,#SN_ADDITION
	subcs r3,r3,r3,lsl#16
	eorcs r7,r7,#0x04

	adds r4,r4,#SN_ADDITION
	subcs r4,r4,r4,lsl#16
	eorcs r7,r7,#0x08

	adds r5,r5,#SN_ADDITION
	subcs r5,r5,r5,lsl#16
	eorcs r7,r7,#0x10

	adds r6,r6,#SN_ADDITION		;@ 0x00200000?
	subcs r6,r6,r6,lsl#16
	biccs r7,r7,#0x20
	movscs r8,r8,lsr#1
	eorcs r8,r8,r9
	orrcs r7,r7,#0x20

	ldr r12,[r2,r7]
	sub r0,r0,#1
	tst r0,#(1<<SN_UPSHIFT)-1
	add lr,lr,r12
	bne innerMixLoop
	eor lr,lr,#0x00008000
	cmp r0,#0
	strpl lr,[r1],#4
	bhi mixLoop

	stmia r2,{r3-r8}			;@ Writeback freq,addr,currentBits,rng
	ldmfd sp!,{r4-r9,lr}
	bx lr
;@----------------------------------------------------------------------------

	.section .text
	.align 2
;@----------------------------------------------------------------------------
sn76496Reset:				;@ In r0 = pointer to struct
	.type   sn76496Reset STT_FUNC
;@----------------------------------------------------------------------------
	mov r1,#0
	mov r2,#(snStateEnd-snStateStart)/4		;@ 64/4=16
rLoop:
	subs r2,r2,#1
	strpl r1,[r0,r2,lsl#2]
	bhi rLoop

	mov r2,#PFEED_SMS
	strh r2,[r0,#rng]
	mov r2,#WFEED_SMS
	strh r2,[r0,#noiseFB]
	mov r2,#calculatedVolumes
	str r2,[r0,#currentBits]	;@ Add offset to calculatedVolumes
	str r1,[r0,r2]				;@ Clear volume 0

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
sn76496W:					;@ In r0 = value, r1 = struct-pointer, right ch.
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
sn76496L_W:					;@ In r0 = value, r1 = struct-pointer, left ch.
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
	stmfd sp!,{r0,r1,r3-r6}

	ldrb r3,[r2,#ch0Att]
	ldrb r4,[r2,#ch1Att]
	ldrb r5,[r2,#ch2Att]
	ldrb r6,[r2,#ch3Att]
	adr r1,attenuation

	ldrb r0,[r2,#ch0AttL]
	ldr r3,[r1,r3,lsl#2]
	ldr r0,[r1,r0,lsl#2]
	orr r3,r3,r0,lsl#16

	ldrb r0,[r2,#ch1AttL]
	ldr r4,[r1,r4,lsl#2]
	ldr r0,[r1,r0,lsl#2]
	orr r4,r4,r0,lsl#16

	ldrb r0,[r2,#ch2AttL]
	ldr r5,[r1,r5,lsl#2]
	ldr r0,[r1,r0,lsl#2]
	orr r5,r5,r0,lsl#16

	ldrb r0,[r2,#ch3AttL]
	ldr r6,[r1,r6,lsl#2]
	ldr r0,[r1,r0,lsl#2]
	orr r6,r6,r0,lsl#16

	add r12,r2,#calculatedVolumes
	mov r1,#15
volLoop:
	movs r0,r1,lsl#31
	movmi r0,r3
	addcs r0,r0,r4
	teq r1,r1,lsl#29
	addmi r0,r0,r5
	addcs r0,r0,r6
	str r0,[r12,r1,lsl#2]
	subs r1,r1,#1
	bne volLoop
	strb r1,[r2,#snAttChg]
	ldmfd sp!,{r0,r1,r3-r6}
	bx lr
;@----------------------------------------------------------------------------
attenuation:						;@ each step * 0.79370053 (-2dB?)
	.long 0x3FFF>>SN_UPSHIFT,0x32CB>>SN_UPSHIFT,0x2851>>SN_UPSHIFT,0x2000>>SN_UPSHIFT
	.long 0x1966>>SN_UPSHIFT,0x1428>>SN_UPSHIFT,0x1000>>SN_UPSHIFT,0x0CB3>>SN_UPSHIFT
	.long 0x0A14>>SN_UPSHIFT,0x0800>>SN_UPSHIFT,0x0659>>SN_UPSHIFT,0x050A>>SN_UPSHIFT
	.long 0x0400>>SN_UPSHIFT,0x032C>>SN_UPSHIFT,0x0285>>SN_UPSHIFT,0x0000>>SN_UPSHIFT
//	.long 0x3FFF,0x32CB,0x2851,0x2000,0x1966,0x1428,0x1000,0x0CB3
//	.long 0x0A14,0x0800,0x0659,0x050A,0x0400,0x032C,0x0285,0x0000
//attenuation1_4:						;@ each step * 0.79370053 (-2dB?)
//	.long 0x0FFF,0x0CB3,0x0A14,0x0800,0x0659,0x050A,0x0400,0x032C
//	.long 0x0285,0x0200,0x0196,0x0143,0x0100,0x00CB,0x00A1,0x0000
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
