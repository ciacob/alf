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

#include <stdlib.h>;
#include <stdio.h>;
#include <string.h>;
#include <math.h>;
#include <sys/time.h>;
#include "MathFloatFuncs.h";
#include "MathDoubleFuncs.h";
#include "DSPFunctions.h";
#include "AS3.h";

struct timeval tv1;
time_t startTime1, endTime1;
double timeDiff1;

const float PI = 3.141592653589793;
char out1[200];

//RIR parameters
#define N 3										// related to the number of virtual sources
#define NN (N * 2 + 1)							// number of virtual sources

#define SWAP(a,b)tempr=(a);(a)=(b);(b)=tempr;
#define DISP(lit) AS3_Trace(AS3_String(lit));	//macro function for printing data for debugging
#define START_TIME {		\
gettimeofday(&tv1, NULL);\
startTime = tv1.tv_usec;	\
}
#define END_TIME {			\
gettimeofday(&tv1, NULL);\
endTime = tv1.tv_usec;	\
}
#define TIME_DIFF(funcName) {	\
sprintf(out1, "it took %i msecs to execute %s \n", ((endTime1 - startTime1)/1000), funcName);\
DISP(out1);\
}

/*
	Class: DSPFunctions.c
*/

/*******************************************************************************
 Group: Fourier Analysis
 
 Function: computeTwiddleFactors()
 Pre computes the twiddle factors needed in the FFT function. The twiddle factors
 are the coeffients which are the roots of unity of the complex unit circle. These 
 must be calculated for each size of FFT. This is accomplished automatically in ALF
 for various algorithms.
 
 Parameters:
 twiddle - array of size 2*fftSize
 fftSize - fftSize
 
 See Also:
 
	<FFT>, <realFFT>
 ******************************************************************************/
void computeTwiddleFactors(float* twiddle, int fftLength, float sign) {
    int k;
    float temp[2];

    for (k = 0; k < fftLength / 2; k++) {
        polarToComplex(1, sign * 2 * PI * (k) / fftLength, temp);
        twiddle[(2 * k)] = temp[0];
        twiddle[(2 * k) + 1] = temp[1];
    }
}
/*	
	Function: getFreq()
	
	Calculates the frequency associated with each bin of the discrete fourier transform.
	
	Parameters:
	
		*freq - Pointer to an array. The array will be filled with the frequency values.
		fftSize - The number of points in the discrete fourier transform.
		fs - The sample rate of the input signal.

*/
void getFreq(float freq[], int frameSize, int fs){

	//Create frequency array
	int n;
	float fnyq = fs/2;								//Nyquist freq
	float deltaF =  fnyq/(frameSize/2);				//Distance between the center frequency of each bin
	for (n = 0; n < (frameSize/2) + 1; n++){
		freq[n] = deltaF*n;
	}
}
/*******************************************************************************
 Function: FFT()
 Function for the fast fourier transform of an array with 
 length fftSize. fftSize must be a power of two.
 
 Parameters:
 *x - Pointer to the input vector.
 fftSize - The size of the FFT to be calculated
 
 See Also:
	<FFTHelper>, <realFFT>
 ******************************************************************************/
void FFT(float* x, int fftLength, float* twiddles, float* output, int sign) {
    float* scratch = (float*) malloc(sizeof (float) * (2 * fftLength));
    FFTHelper(x, fftLength, output, scratch, twiddles, fftLength);

    int i = 0;
    if (sign == -1) {
        for (i = 0; i < fftLength; i++) {
            output[i] /= fftLength;
            output[i + fftLength] /= fftLength;
        }
    }

    free(scratch);
}
/*******************************************************************************
 Function: FFTHelper()
 Calcualtes the fast fourier transform of length N, N must be a power of two
 
 Parameters:
 *x - Pointer to the input vector.
 fftSize - Size of the FFT.
 *X - Pointer to the output vector.
 scratch - Empty array of size fftSize for use in computation of the FFT.
 twiddle - Pointer to an array of twiddle values.
 twiddleLength - Original fft length.
 
 See Also:
	<FFT>, <realFFT>
 ******************************************************************************/
void FFTHelper(float* x, int fftLength, float* X, float* scratch,
        float* twiddle, int imagStart) {
    int k, m, n;
    int skip;
    /* int imagStart = fftLength; */
    int evenItr = fftLength & 0x55555555;

    float* E, *D;
    float* Xp, *Xp2, *XStart;
    float temp[2], temp2[2];

    /* Special Case */
    if (fftLength == 1) {
        X[0] = x[0];
        X[1] = x[imagStart];
        return;
    }

    E = x;

    for (n = 1; n < fftLength; n *= 2) {
        XStart = evenItr ? scratch : X;
        skip = (fftLength) / (2 * n);
        Xp = XStart;
        Xp2 = XStart + (fftLength / 2);
        for (k = 0; k != n; k++) {

            temp[0] = twiddle[2 * (k * skip)];
            temp[1] = twiddle[2 * (k * skip) + 1];

            for (m = 0; m != skip; ++m) {
                D = E + (skip);

                temp2[0] = (*D * temp[0]) - (*(D + imagStart) * temp[1]);
                temp2[1] = (*D * temp[1]) + (*(D + imagStart) * temp[0]);

                *Xp = *E + temp2[0];
                *(Xp + imagStart) = *(E + imagStart) + temp2[1];

                *Xp2 = *E - temp2[0];
                *(Xp2 + imagStart) = *(E + imagStart) - temp2[1];

                Xp = Xp + 1;
                Xp2 = Xp2 + 1;
                E = E + 1;
            }
            E = E + skip;
        }
        E = XStart;
        evenItr = !evenItr;
    }
}
/************************************************************
 Function: freqResp()
 Calculates the frequency response from an ALL POLE transfer function
 
 Parameters:
 lpCE - a pointer to an array holding the linear predictioin coefficients
 resp - a pointer holding an array of bin frequencies
 fftSize - the size (frameSize) of the FFT
 numRows - the number of rows in the lpCE array
 numCols - the number of cols inthe lpCE array
 fs - the sampling frequency
 useDB - a flag that indicates to return in decibels (1) or not (0)
 
 Returns:
 None, values are passed by reference
 
 See Also:
 
	<LPC>
 *************************************************************/
void freqResp(float *lpCE, float *resp, int fftSize, int numRows, int numCols, int useDB) {
	
	float gain = *(lpCE + numCols);						//assign the gain value for access
	float freqInc = PI/(fftSize/2 + 1);
	float rePart, imPart, denom;
	int i, c;
	
	for(i =0; i < (fftSize/2 + 1); i++) { resp[i] = 0; }
	
	for(i = 0; i < (fftSize/2 + 1); i++) {
		rePart = 0;
		imPart = 0;
		
		for(c = 1; c < numCols; c++) {
			rePart += (*(lpCE + c))*cos((float)(-c*i)*freqInc);
			imPart += (*(lpCE + c))*sin((float)(-c*i)*freqInc);
		}
		
		denom = sqrt(pow((1 + rePart),2) + pow((imPart), 2));
		resp[i] += gain/denom;									//!!!important! notice the += sign to accumulate values from each coefficient
		if(useDB) {
			resp[i] = 20*log10(fabs(resp[i]));
		}
	}
}
/*****************************************************
 Function: magSpec()
 Calculates the magnitude spectrum from the complex Fourier transform.
  
 Parameters:
 
	*fft - A pointer to an fft array obtained using realFFT and unpacked.
	*FFT - A pointer to an array, allocated outside, that will hold the magnitude.
	fftSize - An int specifying the length of the FFT.
	useDB - A boolean var indicating to return decibels (1) or no decibels (0).
 
 Returns:
	None, arrays are passed by reference
	
 See Also:
	<FFT>, <realFFT>, <unpackFrequency>
 
 ****************************************************/
void magSpectrum(float fft[], float FFT[], int fftLength, int useDB){
	
	unsigned int i,j = 0;
		
	if(useDB) { 
		for(i = 0; i <= fftLength; i = i + 2){
			FFT[j] = 20*log10(fabs(sqrt(pow(fft[i], 2) + pow(fft[i + 1], 2)))); 
			j++;
		}
	}else{
		for(i = 0; i <= fftLength; i = i + 2){
			FFT[j] = sqrt(pow(fft[i], 2) + pow(fft[i + 1], 2));		
			j++;
		}
	}	
	
}
/*
	Function: pack()
	
	This function is used to put the data in the format it was in after calling realFFT. If this is not called before
	performing an inverse Fourier transform, the proper values will not be calculated.
	
	Parameters:
	
		*in - A pointer to an array that contains the output data from <realFFT> after computing the *INVERSE*.
		fftSize - The number of FFT points used in calculating the spectrum.
	
	See Also:
	
		<unpackFrequency>, <unpackTime> <realFFT>
*/
void pack(float* in, int fftLength) {
    int k;	
		
	in[1] = in[fftLength];		// Set second element to the real part at fs/2
	in[fftLength] = 0;			// Set imaginary component at fs/2 to zero
}
/*******************************************************************************
 Function: realFFT()
 
 Function for the fast fourier transform of a real valued array with length fftSize - fftSize must be a power of two.
 The output of RealFFT is in the form of Re[0], Re[1] ... Re[N/2], Im[0], Im[1], ..., Im[N/2]. All the real values
 are in order followed by the imaginary values. 
 
 Parameters:
 *x - Pointer to the input array.
 *X - Pointer to the output array.
 fftSize - Size of the fft 
 *twiddles - The twiddle factors for the associated fftSize.
 *halfTwiddles - The half twiddle factors for half the fftSize.
 *scratch - An array used for storing values throughout the computation
 sign - Indcates a forward transform (1) or an inverse transform (-1).
 
 See Also:
	<pack>, <unpackFrequency>, <unpackTime>
 ******************************************************************************/
void realFFT(float* x, float *out, int fftLength, float* twiddles, float* halfTwiddles, float* scratch, int sign) {
    float xNew[fftLength];
    //float scratch[2 * fftLength];
    //float halfTwiddles[fftLength];

    int imagStart = fftLength / 2;
    int half = fftLength / 2;
    int quarter = half / 2;
    int i;

    /* Rearrange the original array. Even indexes have become the real part and
     * the odd indicies have become the imaginary parts */
    for (i = 0; i < half; i++) {
        xNew[i] = x[2 * i];
        xNew[i + (imagStart)] = x[2 * i + 1];
    }


    /* If we are taking the FFT */
    if (sign == 1) {

        //computeTwiddleFactors(halfTwiddles, half, sign);
        /* FFT of new array */
        FFTHelper(xNew, half, out, scratch, halfTwiddles, imagStart);


        /* Manipulate tempOut for correct FFT */
        float temp1[2];
        float temp2[2];

        for (i = 1; i < quarter; i++) {
            temp1[0] = out[i];
            temp1[1] = out[i + (imagStart)];

            temp2[0] = out[half - i];
            temp2[1] = out[half - i + (imagStart)];

            out[i] = (0.5)*(temp1[0] + temp2[0]
                    + sign * twiddles[2 * i]*(temp1[1] + temp2[1])
                    + twiddles[(2 * i) + 1]*(temp1[0] - temp2[0]));

            out[i + (imagStart)] = (0.5)*(temp1[1] - temp2[1]
                    - sign * twiddles[2 * i]*(temp1[0] - temp2[0])
                    + twiddles[(2 * i) + 1]*(temp1[1] + temp2[1]));

            out[half - i] = (0.5)*(temp1[0] + temp2[0]
                    - sign * twiddles[2 * i]*(temp1[1] + temp2[1])
                    - twiddles[(2 * i) + 1]*(temp1[0] - temp2[0]));

            out[half - i + (imagStart)] = (0.5)*(-temp1[1] + temp2[1]
                    - sign * twiddles[2 * i]*(temp1[0] - temp2[0])
                    + twiddles[(2 * i) + 1]*(temp1[1] + temp2[1]));
        }

        temp1[0] = out[0];
        temp1[1] = out[(imagStart)];

        out[0] = temp1[0] + temp1[1];
        out[(imagStart)] = temp1[0] - temp1[1];
    }

    /* Inverse FFT of real signal */
    if (sign == -1) {

        /* Manipulate tempOutput for correct FFT */
        float temp1[2];
        float temp2[2];

        for (i = 1; i < quarter; i++) {
            temp1[0] = xNew[i];
            temp1[1] = xNew[i + (imagStart)];

            temp2[0] = xNew[half - i];
            temp2[1] = xNew[half - i + (imagStart)];

            xNew[i] = (0.5)*(temp1[0] + temp2[0]
                    + sign * twiddles[2 * i] * (temp1[1] + temp2[1])
                    - twiddles[(2 * i) + 1] * (temp1[0] - temp2[0]));

            xNew[i + (imagStart)] = (0.5)*(temp1[1] - temp2[1]
                    - sign * twiddles[2 * i]*(temp1[0] - temp2[0])
                    - twiddles[(2 * i) + 1]*(temp1[1] + temp2[1]));

            xNew[half - i] = (0.5)*(temp1[0] + temp2[0]
                    - sign * twiddles[2 * i]*(temp1[1] + temp2[1])
                    + twiddles[(2 * i) + 1]*(temp1[0] - temp2[0]));

            xNew[half - i + (imagStart)] = (0.5)*(-temp1[1] + temp2[1]
                    - sign * twiddles[2 * i]*(temp1[0] - temp2[0])
                    - twiddles[(2 * i) + 1]*(temp1[1] + temp2[1]));
        }

        temp1[0] = xNew[0];
        temp1[1] = xNew[(imagStart)];

        xNew[0] = temp1[0] + temp1[1];
        xNew[(imagStart)] = temp1[0] - temp1[1];

        xNew[0] *= (0.5);
        xNew[imagStart] *= (0.5);

        //computeTwiddleFactors(halfTwiddles, half, sign);
        FFTHelper(xNew, half, out, scratch, halfTwiddles, imagStart);
    }
}
/*
	Function: unpackFrequency()
	
	The output of RealFFT is in the form of Re[0], Re[1] ... Re[N/2], Im[0], Im[1], ..., Im[N/2]. 
	
	This function changes the order to Re[0], Im[0], Re[1], Im[1], ... Re[N/2], Im[N/2]
	
	Parameters:
	
		*in - A pointer to an array that contains the output data from <realFFT>
		fftSize - The length of the FFT calculated.
		
	See Also:
	
		<pack>, <realFFT>, <unpackTime>
*/
void unpackFrequency(float* in, int fftLength) {

	int k;
	float *temp = (float *) malloc(sizeof(float)*(fftLength*2));
    for (k = 0; k <= fftLength + 2; k++) {
        temp[k] = in[k];
    }
	
    for (k = 0; k <= fftLength/2; k++) {
        in[2*k] = temp[k];
		in[2*k + 1] = temp[k + fftLength / 2];
    }

	in[1] = 0;
	in[2*fftLength - 1] = temp[fftLength];
	free(temp);
}
/*
	Function: unpackTime()
	
	This function reorders the values to be in the proper order after resynthesis (IFFT).
	
	Parameters:
	
		*in - A pointer to an array that contains the output data from <realFFT>
		fftSize - The length of the FFT calculated.
	
	See Also:
		<pack>, <unpackFrequency>, <realFFT>
*/
void unpackTime(float* in, int fftLength) {

	int k;
	float *temp = (float *) malloc(sizeof(float)*(fftLength*2));
    for (k = 0; k <= fftLength + 2; k++) {
        temp[k] = in[k];
    }

    for (k = 0; k <= fftLength/2; k++) {
        in[2*k] = temp[k];
		in[2*k + 1] = temp[k + fftLength / 2];
    }
	
	in[2*fftLength - 1] = temp[fftLength];
	free(temp);
}


/***************************************************************************

Group: DSP Algorithms

Function: autoCorr()

Computes the autocorrelation of a given sequence, which is just 
its cross correlation with itself. The algorithm works by taking
the FFT of the sequence and multiplying the FFT by it's complex conjugate. The
inverse FFT of this real valued FFT yields half of the autocorrelation sequence,
such that the first value corresponds to zero-lag.

Parameters:
	audioSeg - a poitner to an array containing the frame of audio we're interested in
	fftSize  - the length of audioSeg (and the fftSize)
	corrData - a pointer to the array that will hold the correlation data. Must be initialized to
		2*fftSize in order to avoid circular convolution.
	corrDataOut - a pointer to the array holding the result of the FFT
	twid - pointer to twiddle factors
	invTwid - pointer to inverse twiddle factors
	halfTwid - pointer to the half twiddle factors
	invHalfTwid - pointer to the inverse half twiddle factors
	scratch - pointer to an arrray holding the scratch data for the FFT

Returns:
	no data: all pass by reference

*****************************************************************/
void autoCorr(float *audioSeg, int fftSize, float *corrData, float* corrDataOut, float *twid,
			  float *invTwid, float *halfTwid, float* invHalfTwid, float *scratch) {
		int i;
		
		//copy data in to corrData
		for (i = 0; i < fftSize; i++) { corrData[i] = audioSeg[i]; }
				  
		// FFT of frame
		realFFT(corrData, corrDataOut, fftSize*2, twid, halfTwid, scratch, 1);
		unpackFrequency(corrDataOut, fftSize*2);
				  
		// Now multiply the FFT by its conjugate....
		float RE, IM;
		for(i = 0; i < (fftSize*2); i = i+2) {
			RE = corrDataOut[i];
			IM = corrDataOut[i+1];
			corrDataOut[i] = RE * RE - (IM * -IM);
			corrDataOut[i+1] = 0;
		}	  
		//repack the FFT and take the ifft		
		pack(corrDataOut, (fftSize*2));
		realFFT(corrDataOut, corrData, (fftSize*2), invTwid, invHalfTwid, scratch, -1);
		unpackTime(corrData, fftSize*2);
		// Rescale the FFT to compensate for frameSize weighting
		float scaleFactor = 2.0/(fftSize*2);
		for(i = 0; i < fftSize*2; i++) { corrData[i] = corrData[i] * (scaleFactor); }
}
/**********************************************************
 Function: iirFilter() 
 Performs filtering with a provided transfer function based on a direct form II -transpose structure
 
 Parameters:
	input - the input sequence that will be used to filter the audio signal
	ouput - the output sequence where the audio will be stored
	seqLen - the length of the input and output sequence (they must be the same)
	gain - the gain of the filter if any
	numCoeffs - an array specifying the numerator coefficients
	denomCoeffs - an array specifying the denominator coefficients
	numOrder - the number of numCoefficients
	denomOrder - the number of denomCoefficients
 
 Format:
 - denomCoeffs: (1 a1  a2  a3 ...... aM), order of denom = M
 - numCoeffs: (1  b1  b2 ....... bN), order of num = N 
 - for proper tf, should have M >= N
 
 Returns:
		None, arrays are passed by reference
 
 ********************************************************/
void iirFilter(float *input, float *output, int seqLen, float gain, float *numCoeffs, float *denomCoeffs, int numOrder, int denomOrder) {
	
	int i, n, d, e;
	float v[denomOrder];						//filter memory for delays
	for(i = 0; i < denomOrder; i++) v[i] = 0;	//init to zeros...
	
	//peform the filtering..........
	for(i = 0; i < seqLen; i++){
		
		//calculate v[n] = input[n] - a1*v[n-1] - a2*v[n-2] - ...... - aM*v[n-M]
		v[0] = input[i];
		for(d = 1; d < denomOrder; d++){
			v[0] -= denomCoeffs[d]*v[d];
		}
		
		//now calculate y[n] = b0*v[n] + b1*v[n-1] + .......+ bN*v[n-N]
		output[i] = 0;
		for(n = 0; n < numOrder; n++){
			output[i] += numCoeffs[n]*v[n];
		}
		output[i] *= gain;
		
		//now, need to shift memory in v[n] = v[n-1], v[n-1] = v[n-2] ......
		for(e = denomOrder - 1; e > 0; e--){
			v[e] = v[e-1];
		}
	}
}
/*********************************************************************
 Function: LPC()
 Performs linear predictive analysis on an audio segment for a desired order. The algorithm 
 works by computing the autocorrelation of the sequency followed by the Levinson Recursion to 
 computed the prediction coefficients.
 
 Parameters:
 audioSeg - a pointer to an array containing the frame of audio of interest
 audioLength - the length of audioSeg ...MUST BE A POWER OF 2!!!!!
 order - the desired order of LP analysis
 lpCE - a pointer for a two dimensional array containing gain and coefficients (Coefficients 
 in first row, gain in second)
 
 Returns:
 Returns an integer indicating whether or not an error ocurred in 
 the algorithm (1 = error, 0 = no error)
 **********************************************************************/
int LPC(float *corrData, int audioLength, int order, float *lpCE){
	int error = 0;
	if (order < 0)	error = 1;					//can't have negative order prediction coefficients
	else if (order > audioLength) error = 1;	//can't have more prediction coefficients than samples
	else {

		//*********************************** LEVINSON RECURSION FOLLOWS *********************************		
		//STEP 1: initialize the variables
		float lpcTemp[order];					//this array stores the partial correlaton coefficients
		float temp[order];						//temporary data for the recursion
		float temp0;
		float A = 0;							//this is the gain computed from the predicition error
		float E, ki, sum;						//zeroth order predictor, weighting factor, sum storage
		int i, j;
		
		for(i = 0; i < order; i++) { lpcTemp[i] = 0.0; temp[i] = 0.0; } //init arrays to zeros
		
		E = corrData[0];						//for the zeroth order predictor
		ki = 0;
		
		//STEP 2:5 follows
		
		for(i = 0; i < order; i++) {
			temp0 = corrData[i+1];
			
			for(j = 0; j < i; j++) { temp0 -= lpcTemp[j]*corrData[i - j]; }
			if(fabs(temp0) >= E){ break; }
			
			lpcTemp[i] = ki = temp0/E;
			E -= temp0*ki;
			
			//copy the data over so we can overwrite it when needed
			for(j=0; j < i; j++){ temp[j] = lpcTemp[j]; }
			
			for(j=0; j < i; j++){ lpcTemp[j] -= ki*temp[i-j-1]; }
		}
				
		//STEP 6: compute the gain associated with the prediction error
		sum = 0;											//assign the pth order coefficients to an output vector and compute the gain A
		for(i = 0; i < order; i++){ sum += lpcTemp[i]*corrData[i + 1]; }
		A = corrData[0] - sum;
		A = sqrt(A);
		
		//ready the lpCE array for the getHarmonics function
		*(lpCE + order + 1) = A;
		*lpCE = 1;
		
		//assign to output array
		for(i = 0; i < order; i++){ *(lpCE + i + 1) = -lpcTemp[i]; }
	}
	return error;
}
/**********************************************************************************
 Function: rir() 
 Generates a room impulse response for the specified room dimensions, speaker
 and microphone positions. An FIR represents the RIR
 
 Parameters:
 fs - the sample rae we wish to operate at
 refCo - the reflection coeffcients, a float between 0 and 1 (ecch strength)
 mic - the 3 dimensional positions of the microphone, in meters (LXWXH)
 room - the 3 dimensional room dimensions (L X W X H)
 src - the 3 dimensional position of the source (L X W X H)
 rirLen - the length of the resulting FIR filter
 
 Returns:
 Returns a float* for the resulting FIR filter
 **********************************************************************************/
float* rir(int fs, float refCo, float mic[], float room[], float src[], int rirLen[]){	
	int i, j, k;
	
	// Index for the sequence
	// nn=-n:1:n;
	float nn[NN];
	for(i=(-1 * N);i<=N;i++) {
		nn[i+N] = (float)i;		
	}
	
	
	// Part of equations 2, 3 & 4
	// rms = nn + 0.5 - 0.5*(-1).^nn;
	// srcs=(-1).^(nn);
	float rms[NN], srcs[NN];
	for(i=0;i<NN;i++) {
		rms[i] = nn[i] + 0.5 - (0.5 * ((float)pow(-1,(double)nn[i])));
		srcs[i] = (float)pow(-1,nn[i]);
	}	
	
	
	// Equation 2
	// xi=srcs*src(1)+rms*rm(1)-mic(1);
	// Equation 3
	// yj=srcs*src(2)+rms*rm(2)-mic(2);
	// Equation 4
	// zk=srcs*src(3)+rms*rm(3)-mic(3);
	float xi[NN], yj[NN], zk[NN];
	for(i=0;i<NN;i++) {
		xi[i] = srcs[i] * src[0] + rms[i] * room[0] - mic[0];
		yj[i] = srcs[i] * src[1] + rms[i] * room[1] - mic[1];
		zk[i] = srcs[i] * src[2] + rms[i] * room[2] - mic[2];
	}
	
	
	// Convert vectors to 3D matrices
	// [i,j,k]=meshgrid(xi,yj,zk);
	float meshOut[NN][NN][3*NN];
	meshgrid_float(xi,yj,zk,&meshOut[0][0][0],NN,NN,3*NN);
	
	
	// Equation 5
	// d=sqrt(i.^2+j.^2+k.^2);
	float d[NN][NN][NN];
	for(k=0;k<NN;k++) {
		for(j=0;j<NN;j++) {
			for(i=0;i<NN;i++) {
				d[i][j][k] = sqrt(pow(meshOut[i][j][k],2) + \
								  pow(meshOut[i][j][k + NN],2) + \
								  pow(meshOut[i][j][k + (2 * NN)],2));			
			}
		}
	}
	
	
	// Similar to Equation 6
	// time=round(fs*d/343)+1;
	float timeMat[NN][NN][NN];	
	for(k=0;k<NN;k++) {
		for(j=0;j<NN;j++) {
			for(i=0;i<NN;i++) {
				timeMat[i][j][k] = round_float(((fs * d[i][j][k] / 343) + 1));
			}
		}
	}
	
	
	// Convert vectors to 3D matrices
	// [e,f,g]=meshgrid(nn, nn, nn);
	float meshOutefg[NN][NN][3*NN];
	meshgrid_float(nn,nn,nn,&meshOutefg[0][0][0],NN,NN,3*NN);
	
	
	// Equation 9
	// c=r.^(abs(e)+abs(f)+abs(g));
	float c[NN][NN][NN];
	double constSum;
	for(k=0;k<NN;k++) {
		for(j=0;j<NN;j++) {
			for(i=0;i<NN;i++) {
				constSum = abs_float(meshOutefg[i][j][k]) + abs_float(meshOutefg[i][j][k + NN]) + abs_float(meshOutefg[i][j][k + 2 * NN]);
				c[i][j][k] = (float)(pow((double)refCo,constSum));
			}
		}
	}
	
	
	// Equation 10
	// e=c./d;
	float e[NN][NN][NN];
	for(k=0;k<NN;k++) {
		for(j=0;j<NN;j++) {
			for(i=0;i<NN;i++) {
				e[i][j][k] = c[i][j][k] / d[i][j][k];
			}
		}
	}
	
	
	// Equation 11
	// h=full(sparse(time(:),1,e(:)));
	int len = (int)pow(NN,3);
	
	// Left channel
	float* retVal = (float *)malloc(sizeof(float)*4);
	maxabs3D_float(&timeMat[0][0][0],NN,NN,NN,retVal);
	rirLen[0] = (int)retVal[3];
	float* rirArr = (float *)calloc(rirLen[0], sizeof(float));
	for(k=0;k<NN;k++) {
		for(j=0;j<NN;j++) {
			for(i=0;i<NN;i++) {
				// TOOK MINUS ONE AWAY FROM BELOW TO OFFSET SO THAT RIR[0] = 0
				rirArr[(int)timeMat[i][j][k] - 1] = rirArr[(int)timeMat[i][j][k] - 1] + e[i][j][k];
			}
		}
	}
	free(retVal);
	
	
	// Setting the time domain representation of the rir for the specified channel
	float* retVal2 = (float *)malloc(sizeof(float)*2);
	maxabs1D_float(rirArr,rirLen[0],retVal2);
	float sum = 0;
	for(i = 0;i < rirLen[0];i++) {
		rirArr[i] = rirArr[i] / retVal2[1];
		sum+=rirArr[i];
	}
	free(retVal2);
	
	return rirArr;	
}


/*********************************************************************
 Group: Spectral Features
 
 Function: bandwidth()
 
 Computes the centroid on a frame-by-frame basis for a vector of sample data

 Parameters:
	x[] - array of FFT magnitude values
	fs - sample frequency	
	winLength - window length

 Returns:
	Returns a float that is the spectral bandwidth of the given audio frame
 
*********************************************************************/
float bandwidth(float spectrum[], float freq[], float centroid, int winLength, int fs){
	
	float *diff = (float *) malloc(sizeof(float)*(floor(winLength/2) + 1));
	int i;
	float band = 0;
	
	//Create frequency array
	float fnyq = fs/2;									//Nyquist freq
	float deltaF =  fnyq/(winLength/2);				//Distance between the center frequency of each bin
	for (i = 0; i < floor(winLength/2) + 1; i++){
		freq[i] = deltaF*(i);
	}
	//Find the distance of each frequency from the centroid
	for (i = 0; i < floor(winLength/2)+1; i++){
		diff[i] = fabs(centroid - freq[i]);	
		
	}
	
	//Weight the differences by the magnitude
	for (i = 0; i < floor(winLength/2)+1; i++){
		band = band + diff[i]*spectrum[i]/(winLength/2);
	}
	
	free(diff);
	return band;
}
/*********************************************************************

 Function: centroid()
 
 Calculates the spectral centroid 

 Parameters:
	spectrum[] - the MAGNITUDE spectrum of the data to compute the centroid of
	fs - the sample frequency
	winLength - the number of points of the FFT taken to compute the associated spectrum

 Returns:
	Returns a float that is the centroid for the given frame

*********************************************************************/
float centroid(float spectrum[], float freq[], int winLength, int fs){
	
	int i;
	float centVal;
	float sumNum = 0;
	float sumDen = 0;
		
	//Calculate Centroid - sum of the frequencies weighted by the magnitude spectrum dided by 
	//the sum of the magnitude spectrum

	for (i = 0; i < (winLength/2) + 1; i++){
		sumNum = spectrum[i]*freq[i] + sumNum;
		sumDen = spectrum[i] + sumDen;
	}
	
	centVal = sumNum/sumDen;

	return centVal;
}
/*
	Function: flux()
	
	Calculates the spectral flux.
	
	Parameters:
	
		spectrum - Pointer to the current spectrum
		spectrumPrev - Pointer to the spectrum from the previous frame
		winLength - The length of the DFT
*/
float flux(float spectrum[], float spectrumPrev[], int winLength){
	
	int i;
	
	//Calculate Flux
	float fluxVal = 0;
	for (i = 0; i < (winLength/2) + 1; i++){
		fluxVal = pow((spectrum[i] - spectrumPrev[i]),2) + fluxVal;
	}
	
	return fluxVal;
}
/*********************************************************************
 Function: intensity()
 
 Calculates the spectral energy

 Parameters:
	spectrum[] - the MAGNITUDE spectrum of the data to 
	winLength - the window length
 
 Returns:
	Returns a float that is the energy for the given frame

*********************************************************************/
float intensity(float spectrum[], int winLength){

	//Find the total energy of the magnitude spectrum
	float totalEnergy = 0;
	int n;
	for (n = 0; n < (winLength/2) + 1; n++){
		totalEnergy = totalEnergy + spectrum[n];
	}

	return totalEnergy;
}
/*********************************************************************
 Function: rolloff()
 
 Calculates the spectral centroid 

 Parameters:
	spectrum[] - the MAGNITUDE spectrum of the data to compute the centroid of
	fs - the sample frequency
	winLength - the window lenghth specified earlier

 Returns:
	Returns a float that is the centroid for the given frame
 
*********************************************************************/
float rolloff(float spectrum[], int winLength, int fs){
	
	float rollPercent = 0.85;
	float *freq = (float *) malloc(sizeof(float)*((winLength/2) + 1));	
	
	//Create frequency array
	float fnyq = fs/2;								//Nyquist freq
	float deltaF =  fnyq/(winLength/2);			//Distance between the center frequency of each bin
	int n;
	for (n = 0; n < (winLength/2) + 1; n++){
		freq[n] = deltaF*(n);
	}
	
	/*
	* Calculate Rolloff
	*/
	
	//Find the total energy of the magnitude spectrum
	float totalEnergy = 0;
	for (n = 0; n < (winLength/2) + 1; n++){
		totalEnergy = totalEnergy + spectrum[n];
	}
	
	//Find the index of the rollof frequency
	float currentEnergy = 0;
	int k = 0;
	while(currentEnergy <= totalEnergy*rollPercent && k <= winLength/2){
		currentEnergy = currentEnergy + spectrum[k];
		k++;
	
	}
		
	//Output the rollof frequency	
	float rollFreq = freq[k-1];
	free(freq);
	return rollFreq;
}
/************************************************************************
*	Function:  hannWindow()
*
*	Parameters:		hann[] - An array that will contain the Hann coefficients.
*					winLength - The number of coefficients to be calculated
*
*	Returns:		Replaces the values in hann[] with the windowed values
*
*************************************************************************/
void hannWindow(float hann[], int winLength){

	int n;
	for (n = 0; n < winLength; n++){
		hann[n] = 0.5*(1 - cos(PI*2*(n)/(winLength - 1)));
	}

}
/************************************************************************
*	Function:  nextPowerOf2()
*
*	Parameters:		number - The number to find the next highest power of two for.
*
*	Returns:		An integer which is the next highest power of two above the argument.
*
*************************************************************************/
int nextPowerOf2(int number){

	unsigned int count = 0;
	number--;
	while(pow(2,count) < sizeof(int)*8){
		
		number = number | number >> (int) pow(2,count);	
		count++;
	}
	number++;
	
    return number;
}
/*******************************************************************************
 Function: polarToComplex()
 Converts polar numbers to complex numbers
 
 Parameters:
 mag - magnitude
 phase - phase
 ans - output array ans[0] = real, ans[1] = imag
 ******************************************************************************/
void polarToComplex(float mag, float phase, float* ans) {
    ans[0] = mag * cos(phase);
    ans[1] = mag * sin(phase);
}
