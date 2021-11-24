# K2Audio
SNK NeoGeo Pocket sound chip emulator for ARM32.

SN76496/SN76489 with stereo extension, from the NeoGeo Pocket.

First alloc chip struct, call reset with chip struct.
Call SN76496Mixer with length, destination and chip struct.
Produces signed 16bit interleaved stereo.
