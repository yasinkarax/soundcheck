#include "AudioRender.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

struct MixerGain { _Atomic(float) target; float current; };
MixerGain *MixerGainCreate(void) {
    MixerGain *g = calloc(1, sizeof(MixerGain));
    if (g) { atomic_init(&g->target, 1); g->current = 1; }
    return g;
}
void MixerGainDestroy(MixerGain *g) { free(g); }
void MixerGainSet(MixerGain *g, float value) {
    atomic_store_explicit(&g->target, isfinite(value) ? fminf(1, fmaxf(0, value)) : 0, memory_order_relaxed);
}
void MixerRender(MixerGain *g, const AudioBufferList *in, AudioBufferList *out) {
    float target = atomic_load_explicit(&g->target, memory_order_relaxed);
    // No locks, allocation, logging, or Objective-C on the audio thread.
    for (UInt32 b = 0; b < out->mNumberBuffers; b++) {
        AudioBuffer dst = out->mBuffers[b];
        if (!dst.mData) continue;
        memset(dst.mData, 0, dst.mDataByteSize);
        if (b >= in->mNumberBuffers) continue;
        AudioBuffer src = in->mBuffers[b];
        if (!src.mData || src.mNumberChannels != dst.mNumberChannels) continue;
        UInt32 count = (src.mDataByteSize < dst.mDataByteSize ? src.mDataByteSize : dst.mDataByteSize) / sizeof(float);
        UInt32 frames = count / dst.mNumberChannels;
        for (UInt32 i = 0; i < count; i++) {
            float t = (float)(i / dst.mNumberChannels + 1) / (float)frames;
            ((float *)dst.mData)[i] = ((const float *)src.mData)[i] * (g->current + (target - g->current) * t);
        }
    }
    g->current = target;
}
