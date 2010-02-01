/*
 Copyright 2009 Music and Entertainment Technology Laboratory - Drexel University
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#ifndef AUDIOCHANNEL_H_
#define AUDIOCHANNEL_H_
#include "CircularBuffer.h";

class AudioChannel {

private:
	int fs, hopSize, fftSize, audioOutputSize;
	float roomLength, roomWidth, roomHeight, sourceLength, sourceWidth, sourceHeight, micLength, micWidth, micHeight;
	double echoStrength;
	bool fftFlag, centroidFlag, magFlag, room;
	bool circularBufferFlag;
	float centroidVal;
	
public:
	AudioChannel();	
	~AudioChannel();
	
	//Init Method
	void initChannel(int fSize, int fftSize, int sampleRate);
	void reInitChannel(int _hopSize, int _fftSize, int _fs, int numCh);
	
	//Clean/Clear methods
	void clearInAudioFrame();
	void clearFlags();
	void clearFFTFrame();
	void resetChannel();	
	
	//Set Methods
	void setAudioFrameSamples(int numSamples);
	void setOutAudioFrameSamples(int numSamples);
	void setCentroidVal(float val);
	void setFFTFlag(bool flagVal);
	void setCentroidFlag(bool flagVal);
	void setMagFlag(bool flagVal);
	void setCircularBufferFlag(bool flagVal);
	void setChannelName(char name[]);
	void setRoom(float rmLength, float rmWidth, float rmHeight, float srcLength, 
				 float srcWid, float srcHt, float micLen, float micWid, float micHt, double echoStr);	
	void setHopSize(int hop);
	int setSampleRate(int _fs);;
	
	//Get methods
	int getFFTSize();
	int getAudioOutputSize();
	int getSampleRate();
	int getHopSize();
	int getOutAudioFrameSamples();
	float getCentroidVal();
	char* getChannelName();
	bool checkRoom(float rmLength, float rmWidth, float rmHeight, float srcLength, 
				   float srcWid, float srcHt, float micLen, float micWid, float micHt, double echoStr);
	bool getFFTFlag();
	bool getCentroidFlag();
	bool getMagFlag();
	bool getCircularBufferFlag();
	
	//Other members
	bool firstFrame, bufferReady, stereo, newRoom;
	char *channelName;
	int inAudioFrameSamples, outAudioFrameSamples;
	
	//Storage Data
	float *fftFrame, *fftOut, *freqData, *magSpectrum, *twiddle, *invTwiddle;
	float *spectrumPrev, *hannCoefficients, *inAudioFrame, *outAudioFrame;
	float *roomSize, *sourcePosition, *micPosition;
	float **inRefPtr, outRefPtr; 
	
	//Circular Buffers
	CircularBuffer *outBuffer, *inBuffer;
		
	// Filtering arrays/vars
	float* filter, *filterTwiddle, *filterInvTwiddle;						
	int filterLen, filterFFTSize;					
	int filterProcessing;
	
};

#endif