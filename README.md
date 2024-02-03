# K2Audio V1.6.3

SNK NeoGeo Pocket sound chip emulator for ARM32.

SN76496/SN76489 with stereo extension, from the NeoGeo Pocket.

## How to use

First alloc chip struct, call reset with chip struct.
Call SN76496Mixer with length, destination and chip struct.
Produces signed 16bit interleaved stereo.
You define SN_UPSHIFT to a number, this is how many times the internal
sampling is doubled. You can add "-DSN_UPSHIFT=2" to the "make" file to
make the internal clock speed 4 times higher (this is the default).

## Projects that use this code

* https://github.com/FluBBaOfWard/NGPDS

## Credits

Fredrik Ahlström

X/Twitter @TheRealFluBBa

https://www.github.com/FluBBaOfWard
