# K2Audio
SNK NeoGeo Pocket sound chip emulator

SN76496/SN76489 with stereo extension, from the NeoGeo Pocket.

First alloc chip struct, call init with chip type.
Call SN76496Mixer with chip struct, length and destination.
Produces signed 16bit interleaved stereo.
