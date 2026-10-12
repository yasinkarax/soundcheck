#include <CoreAudio/CoreAudio.h>
typedef struct MixerGain MixerGain;
MixerGain *MixerGainCreate(void);
void MixerGainDestroy(MixerGain *gain);
void MixerGainSet(MixerGain *gain, float value);
void MixerRender(MixerGain *gain, const AudioBufferList *input, AudioBufferList *output);
