# K2Audio V1.6.1

SNK NeoGeo Pocket sound chip emulator for ARM32.

SN76496/SN76489 with stereo extension, from the NeoGeo Pocket.

## How to use

First alloc chip struct, call reset with chip struct.
Call SN76496Mixer with length, destination and chip struct.
Produces signed 16bit interleaved stereo.

## Projects that use this code

* https://github.com/FluBBaOfWard/NGPDS
* https://github.com/FluBBaOfWard/NGPGBA

## Credits

Fredrik Ahlström

X/Twitter @TheRealFluBBa

https://www.github.com/FluBBaOfWard
