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

								;@ These values are for the SN76489/SN76496 sound chip.
.equ PFEED_SN,	0x4000			;@ Periodic Noise Feedback
.equ WFEED_SN,	0x6000			;@ White Noise Feedback

								;@ These values are for the NCR 8496 sound chip.
.equ PFEED_NCR,	0x4000			;@ Periodic Noise Feedback
.equ WFEED_NCR,	0x4400			;@ White Noise Feedback

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
;@ r0  = mix length.
;@ r1  = mixerbuffer.
;@ r2 -> r5 = pos+freq.
;@ r6  = currentBits.
;@ r7  = noise generator.
;@ r8  = noise feedback.
;@ lr  = mixer reg.
;@ r12 = snptr.
;@----------------------------------------------------------------------------
sn76496Mixer:				;@ r0=len, r1=dest, r12=snptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r9,lr}
	ldmia snptr,{r2-r8,lr}		;@ Load freq/addr0-3, currentBits, rng, noisefb, attChg
	tst lr,#0xff
	blne calculateVolumes
;@----------------------------------------------------------------------------
mixLoop:
	mov lr,#0x80000000
innerMixLoop:
	adds r2,r2,#0x00400000
	subcs r2,r2,r2,lsl#16
	eorcs r6,r6,#0x04

	adds r3,r3,#0x00400000
	subcs r3,r3,r3,lsl#16
	eorcs r6,r6,#0x08

	adds r4,r4,#0x00400000
	subcs r4,r4,r4,lsl#16
	eorcs r6,r6,#0x10

	adds r5,r5,#0x00400000		;@ 0x00200000?
	subcs r5,r5,r5,lsl#16
	biccs r6,r6,#0x20
	movscs r7,r7,lsr#1
	eorcs r7,r7,r8
	orrcs r6,r6,#0x20

	ldr r9,[snptr,r6]
	add lr,lr,r9
	sub r0,r0,#1
	tst r0,#3
	bne innerMixLoop
	eor lr,lr,#0x00008000
	cmp r0,#0
	strpl lr,[r1],#4
	bhi mixLoop

	stmia snptr,{r2-r7}			;@ Writeback freq,addr,currentBits,rng
	ldmfd sp!,{r4-r9,lr}
	bx lr
;@----------------------------------------------------------------------------

	.section .text
	.align 2

;@----------------------------------------------------------------------------
sn76496Reset:				;@ r0 = chiptype SMS/SN76496, snptr=r12=pointer to struct
;@----------------------------------------------------------------------------

	cmp r0,#1
	adr r0,SMSFeedback
	addeq r0,r0,#12
	addhi r0,r0,#24
	ldmia r0,{r1-r3}
	adr r0,noiseFeedback
	str r2,[r0],#8
	str r3,[r0]

	mov r0,#0
	mov r2,#snSize/4			;@ 60/4=15
rLoop:
	subs r2,r2,#1
	strpl r0,[snptr,r2,lsl#2]
	bhi rLoop
	strh r1,[snptr,#noiseFB]
	mov r1,#calculatedVolumes
	str r1,[snptr,#currentBits]
	str r0,[snptr,r1]
	mov r0,#0xFF
	strb r0,[snptr,#ggStereo]

	bx lr

;@----------------------------------------------------------------------------
sn76496SaveState:		;@ In r0=destination, r1=snptr. Out r0=state size.
	.type   sn76496SaveState STT_FUNC
;@----------------------------------------------------------------------------
	mov r2,#snSize
	stmfd sp!,{r2,lr}

	bl memcpy

	ldmfd sp!,{r0,lr}
	bx lr
;@----------------------------------------------------------------------------
sn76496LoadState:		;@ In r0=snptr, r1=source. Out r0=state size.
	.type   sn76496LoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	mov r2,#snSize
	bl memcpy

	ldmfd sp!,{lr}
;@----------------------------------------------------------------------------
sn76496GetStateSize:	;@ Out r0=state size.
	.type   sn76496GetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	mov r0,#snSize
	bx lr
;@----------------------------------------------------------------------------
SMSFeedback:
	.long PFEED_SMS
	mov r0,#PFEED_SMS			;@ Periodic noise
	movne r0,#WFEED_SMS			;@ White noise
SNFeedback:
	.long PFEED_SN
	mov r0,#PFEED_SN			;@ Periodic noise
	movne r0,#WFEED_SN			;@ White noise
NCRFeedback:
	.long PFEED_NCR
	mov r0,#PFEED_NCR			;@ Periodic noise
	movne r0,#WFEED_NCR			;@ White noise

;@----------------------------------------------------------------------------
sn76496W:					;@ r0 = value, snptr = r12 = struct-pointer
;@----------------------------------------------------------------------------
	tst r0,#0x80
	andne r2,r0,#0x70
	strbne r2,[snptr,#snLastReg]
	ldrbeq r2,[snptr,#snLastReg]
	movs r2,r2,lsr#5
	add r1,snptr,r2,lsl#2
	bcc setFreq
doVolume:
	and r0,r0,#0x0F
	ldrb r2,[r1,#ch0Att]
	eors r2,r2,r0
	strbne r0,[r1,#ch0Att]
	strbne r2,[snptr,#snAttChg]
	bx lr

setFreq:
//	cmp r2,#3					;@ Noise channel
//	beq setNoiseFreq
	cmp r2,#2
	bhi setNoiseFreq
	bxmi lr
	tst r0,#0x80
	andeq r0,r0,#0x3F
	movne r0,r0,lsl#4
	strbeq r0,[r1,#ch0Reg+1]
	strbne r0,[r1,#ch0Reg]
	ldrh r0,[r1,#ch0Reg]
	movs r0,r0,lsl#2
	cmp r0,#0x0180				;@ We set any value under 6 to 1 to fix aliasing.
	movmi r0,#0x0040			;@ Value zero is same as 1 on SMS.
	strh r0,[r1,#ch0Frq]

	cmp r2,#2					;@ Ch2
	ldrbeq r1,[snptr,#ch3Reg]
	cmpeq r1,#3
	strheq r0,[snptr,#ch3Frq]
	bx lr

setNoiseFreq:
	and r1,r0,#3
	strb r1,[snptr,#ch3Reg]
	tst r0,#4
noiseFeedback:
	mov r0,#PFEED_SMS			;@ Periodic noise
	strh r0,[snptr,#rng]
	movne r0,#WFEED_SMS			;@ White noise
	strh r0,[snptr,#noiseFB]
	mov r2,#0x0400				;@ These values sound ok
	mov r2,r2,lsl r1
	cmp r1,#3
	ldrheq r2,[snptr,#ch2Frq]
	strh r2,[snptr,#ch3Frq]
	bx lr

;@----------------------------------------------------------------------------
sn76496L_W:					;@ r0 = value, snptr = r12 = struct-pointer
;@----------------------------------------------------------------------------
	tst r0,#0x80
	andne r2,r0,#0x70
	strbne r2,[snptr,#snLastRegL]
	ldrbeq r2,[snptr,#snLastRegL]
	movs r2,r2,lsr#5
	add r1,snptr,r2,lsl#2
	bcc setFreqL
doVolumeL:
	and r0,r0,#0x0F
	ldrb r2,[r1,#ch0AttL]
	eors r2,r2,r0
	strbne r0,[r1,#ch0AttL]
	strbne r2,[snptr,#snAttChg]
	bx lr

setFreqL:
	cmp r2,#3					;@ Noise channel
	bxeq lr
	tst r0,#0x80
	andeq r0,r0,#0x3F
	movne r0,r0,lsl#4
	strbeq r0,[r1,#ch0Reg+1]
	strbne r0,[r1,#ch0Reg]
	ldrh r0,[r1,#ch0Reg]
	movs r0,r0,lsl#2
	cmp r0,#0x0180				;@ We set any value under 6 to 1 to fix aliasing.
	movmi r0,#0x0040			;@ Value zero is same as 1 on SMS.
	strh r0,[r1,#ch0Frq]

	cmp r2,#2					;@ Ch2
	ldrbeq r1,[snptr,#ch3Reg]
	cmpeq r1,#3
	strheq r0,[snptr,#ch3Frq]
	bx lr

;@----------------------------------------------------------------------------
calculateVolumes:
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r6}

	adr r1,attenuation1_4

	ldrb r0,[snptr,#ch0Att]
	ldr r3,[r1,r0,lsl#2]
	ldrb r0,[snptr,#ch0AttL]
	ldr r0,[r1,r0,lsl#2]
	orr r3,r3,r0,lsl#16

	ldrb r0,[snptr,#ch1Att]
	ldr r4,[r1,r0,lsl#2]
	ldrb r0,[snptr,#ch1AttL]
	ldr r0,[r1,r0,lsl#2]
	orr r4,r4,r0,lsl#16

	ldrb r0,[snptr,#ch2Att]
	ldr r5,[r1,r0,lsl#2]
	ldrb r0,[snptr,#ch2AttL]
	ldr r0,[r1,r0,lsl#2]
	orr r5,r5,r0,lsl#16

	ldrb r0,[snptr,#ch3Att]
	ldr r6,[r1,r0,lsl#2]
	ldrb r0,[snptr,#ch3AttL]
	ldr r0,[r1,r0,lsl#2]
	orr r6,r6,r0,lsl#16

	add r2,snptr,#calculatedVolumes
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
	str r0,[r2,r1,lsl#2]
	subs r1,r1,#1
	bne volLoop
	strb r1,[snptr,#snAttChg]
	ldmfd sp!,{r0-r6}
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