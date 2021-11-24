/*
*/

#ifndef SN76496_HEADER
#define SN76496_HEADER

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	u16 ch0Frq;
	u16 ch0Cnt;
	u16 ch1Frq;
	u16 ch1Cnt;
	u16 ch2Frq;
	u16 ch2Cnt;
	u16 ch3Frq;
	u16 ch3Cnt;

	u32 currentBits;

	u32 rng;
	u32 noiseFB;

	u8 snAttChg;
	u8 snLastReg;
	u8 snLastRegL;
	u8 snPadding[1];

	u16 ch0Reg;
	u16 ch0Att;
	u16 ch1Reg;
	u16 ch1Att;
	u16 ch2Reg;
	u16 ch2Att;
	u16 ch3Reg;
	u16 ch3Att;

	u16 ch0RegL;
	u16 ch0AttL;
	u16 ch1RegL;
	u16 ch1AttL;
	u16 ch2RegL;
	u16 ch2AttL;
	u16 ch3RegL;
	u16 ch3AttL;

	s16 calculatedVolumes[16*2];
} SN76496;

/**
 * Reset/initialize SN76496 chip.
 * @param  *chip: The SN76496 chip.
 */
void sn76496Reset(SN76496 *chip);

/**
 * Saves the state of the SN76496 chip to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The SN76496 chip to save.
 * @return The size of the state.
 */
int sn76496SaveState(void *destination, const SN76496 *chip);

/**
 * Loads the state of the SN76496 chip from the source.
 * @param  *chip: The SN76496 chip to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int sn76496LoadState(SN76496 *chip, const void *source);

/**
 * Gets the state size of a SN76496.
 * @return The size of the state.
 */
int sn76496GetStateSize(void);

/**
 * Runs the sound chip for len number of cycles, output is 1/4 samples,
 * so if actual chip would output 218kHz this mixer would render at ~55kHz.
 * @param  *len: Number of cycles to run.
 * @param  *dest: Pointer to buffer where sound is rendered.
 * @param  *chip: The SN76496 chip.
 */
void sn76496Mixer(int len, void *dest, SN76496 *chip);

/**
 * Write value to SN76496 chip port#0.
 * @param  value: value to write.
 * @param  *chip: The SN76496 chip.
 */
void sn76496W(u8 val, SN76496 *chip);

/**
 * Write value to SN76496 chip port#1.
 * @param  value: value to write.
 * @param  *chip: The SN76496 chip.
 */
void sn76496L_W(u8 val, SN76496 *chip);


#ifdef __cplusplus
}
#endif

#endif // SN76496_HEADER
