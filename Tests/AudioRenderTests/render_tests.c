#include "AudioRender.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
int main(void) {
    MixerGain *g = MixerGainCreate();
    assert(g);
    float source[] = {1, -1, 1, -1};
    float dest[6] = {99,99,99,99,99,99};
    AudioBufferList in = {1, {{2, sizeof(source), source}}};
    AudioBufferList out = {1, {{2, sizeof(dest), dest}}};
    MixerRender(g, &in, &out);
    assert(dest[0] == 1 && dest[1] == -1 && dest[4] == 0 && dest[5] == 0);
    MixerGainSet(g, 0.5);
    MixerRender(g, &in, &out);
    assert(dest[0] == 0.75 && dest[1] == -0.75 && dest[2] == 0.5 && dest[3] == -0.5);
    MixerRender(g, &in, &out);
    assert(dest[0] == 0.5 && dest[1] == -0.5);
    MixerGainSet(g, 0);
    MixerRender(g, &in, &out);
    MixerRender(g, &in, &out);
    for (int i=0; i<6; i++) assert(dest[i] == 0);
    MixerGainSet(g, 9);
    MixerRender(g, &in, &out);
    assert(dest[2] == 1);
    MixerGainSet(g, NAN);
    MixerRender(g, &in, &out);
    assert(dest[2] == 0);
    MixerGainDestroy(g);
    puts("All audio render checks passed.");
}
