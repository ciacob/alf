﻿/*
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


package{
	
	import cmodule.ALFPackage.CLibInit;	
	import flash.utils.ByteArray;
	import flash.events.*;
	import flash.net.*;
	
		
	/*
		Class: DATF.as
		
		The DSP Audio Toolkit for Flash. The DATF is a wrapper class that provides simple interfacing with C/C++ DSP functions via Adobe Alchemy. 
	*/
	public class DATF extends EventDispatcher{
	
		// Basic members
		private var hopSize:uint;
		private var fftSize:uint;
		private var hopSizeBytes:uint;
		private var samplesToWrite:int;		
		private var numBytes:int;
		private var fs:uint;
		private var i:int;
		private var numCh:uint = 1
		private var temp:int;
		private var tempNum:Number;
		private var chVal:Number;		
		private const sizeofFloat:Number = 4;
		private var STEREO:Boolean;
		private var firstFrame:Boolean = true;
		public const PROCESS_FRAME:String = "processFrame";
		
		
		// Array Handling
		var chPtrArray:Array;					// Array of the shared AS/C pointers of the AudioChannel class in ALFPackage.cpp
		var chInArray:Array;					// Array to the audio frame in the AudioChannel class in ALFPackage.cpp
		var chOutArray:Array;					// Array to the outAudioFrame in the AudioChannel class in ALFPackage.cpp
		var chSamplesPtrArray:Array;			// Array that tracks pointers indicating the number of samples contained in audio 
												// frame for each AudioChannel object
		var leftCh:Array;						// Pointers of the left channel
		var rightCh:Array;						// Pointers of the right channel
		var filterFIRPtrArray:Array;
		var filterIIRPtrArray:Array;		
		var freqResp:Array;
		var autoArray:Array;
		var chPtr:int, magPtr:int;
		var initPos:Number;						// Position of URL Loader data passed to DATF
		var ch:uint;							// For looping through the channels if stereo		

		// C Library
		public static var lib:Object;			// Object that is used to 
		public static var libLoader:CLibInit;	// Class that exposes functionality from your C code	
		public static var cRAM:ByteArray;		// Shared AS/C memory
		public var CMEMORY:Boolean = false;
		
		// Storage variables
		public var FFTArray:Array, IFFTArray:Array, magArray:Array, harmFreqs:Array, harmAmps:Array;
		
		// Timing
		private var time1:Number = 0, time2:Number;
		
		/*
			Topic: Usage
			
			The DATF is designed for developers who want more control over the dynamic audio capabilities of Actionscript. For simpler 'out of the box'
			functionality, use the <ALF.as>. The DATF provides a means to access a variety of DSP functions that are written in C/C++ and then compiled with 
			the Alchemy enabled g++ compiler to create bytecode that is optimized for the Actionscript Virtual Machine. The ALFPackage.swc file you include
			in your project (process outlined in the <Introduction>) contains all the functions that are called from the DATF. A simple example is given below.
			Note that this is a scaled down version of what ALF does. Again, the reason for using DATF rather than ALF is to implement the dynamic audio 
			playback in a different manner.
			
			Topic: Example
			
			(start code)
			
			package {

				// Utiliites	
				import flash.net.URLRequest;
				import flash.utils.ByteArray;
				import flash.utils.Endian;
				import DATF;

				// Media	
				import flash.media.Sound;
				import flash.media.SoundChannel;
				import flash.display.MovieClip;

				// Events
				import flash.events.SampleDataEvent;
				import flash.events.Event;
				import flash.events.IOErrorEvent;


				public class DATFtest extends MovieClip{
					
					// Audio vars
					var DSP:DATF;
					var mp3Bytes:ByteArray;
					var audio:Sound;
					var mp3Audio:Sound;
					var audioCh:SoundChannel;
					var mp3Position:uint = 0;
					var STEREO:Boolean = true;
					var hopSize:uint = 2048;
					var fs:uint = 44100;
					
					// C interface memory vars
					var cRAM:ByteArray;
					var audioPtrs:Array;
					var leftBufferStatus:Array;
					var rightBufferStatus:Array;						

					// Framing		
					var numSamplesToPlay:Number;
					var leftSample:Number;
					var rightSample:Number;			
					const sizeofFloat:Number = 4;
					var i:uint = 0;
					
					public function DATFtest(){
						
						var song:String = "Testsong.mp3";
						
						var mp3Request:URLRequest = new URLRequest(song);						// Load filename
						mp3Bytes = new ByteArray();												// For raw samples from file
						mp3Bytes.endian = Endian.LITTLE_ENDIAN;									
						
						audio = new Sound();													// Sound object for playback
						mp3Audio = new Sound();													// Sound object for audio file sample extraction
						audioCh = new SoundChannel();											
						
						// C/ActionScript memory 
						cRAM = new ByteArray();
						leftBufferStatus = new Array();
						rightBufferStatus = new Array();
						audioPtrs = new Array();
						
						mp3Audio.addEventListener(IOErrorEvent.IO_ERROR, mp3LoadError);			// Handle failed load
						mp3Audio.addEventListener(Event.COMPLETE, mp3Loaded);					// Load completed
						audio.addEventListener(SampleDataEvent.SAMPLE_DATA, mp3AudioCallback);	// Main callback
						mp3Audio.load(mp3Request);

					}

					//Load MP3 file and play
					private function mp3Loaded(evt:Event):void{

						trace('mp3 Loaded!');

						//Initilize the DATF
						DSP = new DATF(hopSize, STEREO, fs, 0);
						
						cRAM = DSP.getCRAM();													// Pointer to shared AS/C memory
						audioPtrs = DSP.getChOutPtrs();											// Pointers to the L/R channels							
						
						// Read first frame
						mp3Bytes.position = 0;
						mp3Position += mp3Audio.extract(mp3Bytes,hopSize,mp3Position);			// Extract samples	

						audioCh = audio.play();													// Begin playback
						audioCh.addEventListener(SampleDataEvent.SAMPLE_DATA, mp3AudioCallback);
					}

					private function mp3LoadError(error:IOErrorEvent):void{
						trace('Error loading mp3: '+error);
					}

					private function mp3AudioCallback(evt:SampleDataEvent):void {

						mp3Bytes.position = 0;
						DSP.setFrame(mp3Bytes, "float");				// Load the audio frame into the C buffer
																							
						// You must check to see if audio is being synthesized by DATF (i.e. using reverb)		
						leftBufferStatus = DSP.checkOutputBuffer("left");										
						rightBufferStatus  = DSP.checkOutputBuffer("right");		
						numSamplesToPlay = Math.min(leftBufferStatus[1], rightBufferStatus[1]);		// Find how many samples to play

						for(i = 0; i < numSamplesToPlay; i++){
													
							cRAM.position = audioPtrs[0] + i*sizeofFloat;		//position for leftCh
							leftSample = cRAM.readFloat();
							cRAM.position = audioPtrs[1] + i*sizeofFloat;		//position for rightCh
							rightSample = cRAM.readFloat();
							
							evt.data.writeFloat(leftSample);
							evt.data.writeFloat(rightSample);
						}								
											
						//Extract audio data from sound object
						mp3Bytes.position = 0;
						mp3Position += mp3Audio.extract(mp3Bytes,hopSize,mp3Position);			// Extract samples	
					}
				}
			} //end package
			
			(end code)
			
		*/
		
		/*
			Group: Constructor
		
			Constructor: DATF
			
			Constructor to create a DATF object. This constructor initializes the shared memory between 
			Actionscript and C/C++. Only mono and stereo files are accepted. The C/C++ library is included via the line 
			
			:import cmodule.ALFPackage.CLibInit;						
			
			Parameters:
			
				_hopSize - The hop between audio frames. This is also the number of samples read in on each frame, except the first frame
						   where twice the number of samples are read
				_STEREO - A boolean indicating whether the file is mono or stereo (False for mono, true for stereo)
				_fs - The sample frequency
				frameLookAhead - The number of frames that will be processed before audio playback begins
		*/
		public function DATF(_hopSize:uint, _STEREO:Boolean, _fs:uint, frameLookAhead:Number):void{						
			
			// Save/set parameters
			hopSize = _hopSize;
			fftSize = hopSize;
			hopSizeBytes = 2 * hopSize;		// For .wav data
			STEREO = _STEREO;
			fs = _fs;
			
			if(STEREO){ numCh = 2;}					
			if(!CMEMORY){ initCLibrary();}
			
			// Arrays containing poiter values to shared AS/C memory
			chPtrArray = new Array()
			chInArray = new Array();
			chOutArray = new Array();
			chSamplesPtrArray = new Array();
			filterFIRPtrArray = new Array();			
			filterIIRPtrArray = new Array();		
			autoArray = new Array();	
			
			// Initialize left channel
			leftCh = new Array();
			leftCh = lib.initAudioChannelC("leftCh", fs, hopSize, frameLookAhead);  	// calls the Alchemy library to initialize memory
			chPtrArray.push(leftCh[0]);							
			chInArray.push(leftCh[1]);
			chOutArray.push(leftCh[2]);
			chSamplesPtrArray.push(leftCh[3]);
			filterFIRPtrArray.push(leftCh[4]);
			filterIIRPtrArray.push(leftCh[5]);		
			
			// Initialize right channel if necessary
			if(STEREO){
				numCh = 2;
				rightCh = new Array();	
				rightCh = lib.initAudioChannelC("rightCh", fs, hopSize, frameLookAhead);			
				chPtrArray.push(rightCh[0]);
				chInArray.push(rightCh[1]);
				chOutArray.push(rightCh[2]);
				chSamplesPtrArray.push(rightCh[3]);
				filterFIRPtrArray.push(leftCh[4]);
				filterIIRPtrArray.push(leftCh[5]);
			}

			//initialize storage arrays
			harmAmps = new Array();
			harmFreqs = new Array();
			FFTArray = new Array();
			IFFTArray = new Array();
			magArray = new Array();
		}
		
		private function initCLibrary():void{

			var ns:Namespace = new Namespace("cmodule.ALFPackage");	// Get the namespace of the C module
			cRAM = (ns::gstate).ds;									// cRAM is a variable representing the shared ALCHEMY/C memory
			libLoader = new CLibInit();								// Creating the class that exposes functionality from C
			lib = libLoader.init();									// init() function initializes the C code caling your main() function in C
			
			CMEMORY = true;
		}		
		
		/**********************************************
		* DATF Functions
		***********************************************/
		/*
			Group: Audio Framing
		
			Function: setFrame
			
			This function copies the data from a ByteArray into the shared Actionscript/C memory. The C flags are reset and then
			the C input buffer is polled to determine if it can accept more data without overrunning itself. If a write is deemed
			safe, the number of available samples is calculated and then written to the shared memory, the number of samples is
			also written to the memory for proper processing by C functions.
			
			Parameters:
			
				audio - A ByteArray object containing raw sample data. For .wav files URLLoader can be used if passed as 
						URLLoader.data.
				type - A string specifying 'float' or 'short' datatype.
			
			Returns:
			
				Returns 1 if data was written, 0 if no data was written
			See Also:
			
				<DATF>, <AudioChannel.cpp>
				
			Example: 
			
			If the URLLoader called is 'wavData', then the function call would be:
				
			> DATF.setFrame(wavData.data, "short"); 			
		*/
		public function setFrame(audio:ByteArray, type:String):int{

			// resset flags from the last frame
			for(ch = 0; ch < numCh; ch++){ lib.resetFlagsC(chPtrArray[ch]); }

			// Need to check here to determine if we need to write more data to the inputBuffer
			// chReady indicates if its ready or not bwased on pointer positions
			var chReady:int = 0;
			for(ch = 0; ch < numCh; ch++) { chReady = lib.checkInputBufferC(chPtrArray[ch]); }
			type = type.toLowerCase();
			
			switch(type){
				case "short":	numBytes = 2;	break;				
				case "float":	numBytes = 4;	break;				
				default:		trace("Invalid data type, must be 'short' or 'float'.");
			}
			
			if(chReady){
				
				// Calculate the number of samples to play
				if(audio.bytesAvailable >= hopSize*numBytes*numCh) {
					samplesToWrite = hopSize;
					/*if(firstFrame){
						samplesToWrite = hopSize*2;
						firstFrame = false;
					}*/				
					
				} else {
					samplesToWrite = audio.bytesAvailable/(numCh*numBytes);
				}

				// To get rid of erroneous samples from the previous frame, we clear the input audio frames
				for(ch = 0; ch < numCh; ch++) { lib.clearAudioFrameC(chPtrArray[ch]); }				
				
				var temp:Number;
				switch(type){
					
					case "short":	for(i = 0; i < samplesToWrite; i++) {				
										
										for(ch = 0; ch < numCh; ch++){
												cRAM.position = (chInArray[ch] + sizeofFloat*i);												
												cRAM.writeFloat(audio.readShort()/32768.0);
										}				
									}
									break;
					
					case "float":	for(i = 0; i < samplesToWrite; i++) {				
										for(ch = 0; ch < numCh; ch++){
												cRAM.position = chInArray[ch] + sizeofFloat*i;
												temp = audio.readFloat();
												cRAM.writeFloat(temp);												
										}				
									}
									break;
					
					default:		trace("Invalid data type.");
				}
				
				
				//This informs the AudioChannel Class how many samples are in the audioFrame Buffer
				for(ch = 0; ch < numCh; ch++){
					cRAM.position = chSamplesPtrArray[ch];
					cRAM.writeInt(samplesToWrite);
					lib.setInputBufferC(chPtrArray[ch]);
				}
				
				dispatchEvent(new Event(PROCESS_FRAME));				
			}		
			
			return chReady;
		}
		
		/*
			Group: Basic Library Functions
		
			Function: FFT
			
			Computes the Fast Fourier Transform (FFT) of the current frame.
			
			Parameters:
			
				_fftSize - The nuber of DFT points to be used in calculating the Discrete Fourier Transform. Enter 0 for the default
						   behavior. The default is the next power of two greater than the hopSize and is the recommneded way to
						   compute the DFT.						   
			
			Returns:
			
				An array of alternating real and complex values.
			
			See Also:
			
				<IFFT()>,
				<magSpectrum()>
		*/
		public function FFT(_fftSize:uint):Array{

			if(_fftSize == 0){
				fftSize = lib.getFFTSizeC(chPtrArray[0]);
			}
			FFTArray = [];
			
			// Set shared memory position to fftFrame
			cRAM.position = lib.getComplexSpectrumC(chPtrArray[0]);
			for(i = 0; i < fftSize; i++){			
				FFTArray.push(cRAM.readFloat());
			}			
			
			return FFTArray;
		}
		
		/*
			Function: IFFT
			
			Performs an Inverse Fourier Transform on the current frame.
			
			Parameters:
			
				fftSize - The number of IDFT points to be used in calculating the Inverse Fourier Transform. For reconstruction
						  of a signal, this number needs to be the same as the fftSize used when the forward transform was calculated.
			
			Returns:
			
				An array of sample points.
						
			
			See Also:
			
				<FFT()>
		*/
		public function IFFT(fftSize:uint):Array{
			lib.performIFFTC(chPtrArray[0]);
			
			return IFFTArray;
		}
		
		/*
			Method: magSpectrum
			
			Calculates the magnitude spectrum from the complex frequency spectrum. To calclate a DFT of another size other than
			the framSize, use <FFT()> first with the desired hopSize as a parameter and then call magSpec().
			
			Parameters:
			
				_fftSize - The size of the FFT used in calculating the spectrum. A value of 0 sets this to the default, which is 
						   the greatest power of two higher than the frame size.
						   
				useDB - A value of 1 will return the magnitude spectrum in decibels, 0 for unmodified magnitude.
			
			See Also:
			
				<FFT()>
		*/
		public function magSpectrum(_fftSize:int, useDB:Number):Array{
			
			if(_fftSize == 0){
				fftSize = lib.getFFTSizeC(chPtrArray[0]);
			}
			
			// Get pointer position to magnitude spectrum in shared mem
			magPtr = lib.getMagSpectrumC(chPtrArray[0], useDB);
			cRAM.position = magPtr;
			
			// Reset array
			magArray = [];

			for(i = 0; i <= Math.floor(fftSize/2); i++){			
				magArray.push(cRAM.readFloat());
			}

			return magArray;
		}
		
		/*
			Group: Spectral Features
		
			All spectral features are computed on mono audio. For stereo files, the channels are averaged, then the feature
			value is computed on each frame. This does not effect playback, only the calculation of the feature values.
			
			Function: getBandwidth
			
			Calculates the spectral bandwidth for the current frame.
			
			Returns:
			
				The spectral bandwidth.
				
		*/
		public function getBandwidth():Number{
			
			var band:Number;
			band = lib.getBandwidthC(chPtrArray[0]);
						
			return band;
		}				
		
		/*					
			Function: getCentroid
			
			Calculates the spectral centroid for the current spectral data.
			
			Returns:
			
				The spectral centroid.
				
		*/
		public function getCentroid():Number{
			
			var cent:Number;
			cent = lib.getCentroidC(chPtrArray[0]);
			
			return cent;
		}
		
		/*				
			Function: getFlux
			
			Calculates the change in spectral energy between the current frame and the previous frame.
			
			Returns:
			
				The spectral flux.
		*/
		public function getFlux():Number{
			
			var flux:Number;
			flux = lib.getFluxC(chPtrArray[0]);
			
			return flux;
		}		
		
		/*
			Function: getIntensity
			
			Calculates the spectral intensity for the current frame.
			
			Returns:
			
				The spectral intensity.
		*/
		public function getIntensity():Number{
			
			var inten:Number;
			inten = lib.getIntensityC(chPtrArray[0]);
			
			return inten;
		}
		
		/*
			Function: getRolloff
			
			Calculates the spectral rolloff for the current frame.
			
			Returns:
			
				The spectral rolloff.

		*/
		public function getRolloff():Number{
			
			var roll:Number;
			roll = lib.getRolloffC(chPtrArray[0]);
			
			return roll;
		}		

		public function getBeats(w:Array, printFrame:Number):Array
		{
			var beat:Array =  lib.getBeatsC(chPtrArray[0], w[0], w[1], w[2], w[3], w[4], w[5], w[6], printFrame);
			//trace('DATF w: ' +w[0]);
			autoArray = [];
			//trace(beat[8]);
			for (var i:int = 0; i < 120; i++)
			{
				cRAM.position = beat[9] + sizeofFloat*i;
				tempNum = cRAM.readFloat();
				autoArray.push(tempNum);
				//if(i ==  0){ trace(tempNum);}
			}
			return beat;									
		}
		public function getAuto():Array
		{
			return autoArray;
		}		
		/*
			Group: Spectral Analysis
		
			Function: getHarmonicAmplitudes
			
			A function to return the amplitude of the harmonics.

			Returns:
			
				Returns an array containing the partial amplitudes populated by calling the getHarmonics function.
				These amplitudes are specified in decibels (dB). Note: getHarmonics() must be called before this function
				in order to populate the array with meaningful data.

			See Also:
			
				<getHarmonicFrequencies()>,
				<getHarmonics()>
		*/		
		public function getHarmonicAmplitudes():Array {
			return harmAmps;
		}

		/*
			Function: getHarmonicFrequencies
			
			Returns an array containing the partial's frequencies populated by callilng the getHarmonics function.
			The frequencies indicated are in Hertz (Hz). Note: getHarmonics() must be called before this function
			in order to return meaningful data.
			
			See Also:
			
				<getHarmonics()>,
				<getHarmonicAmplitudes()>
		*/
		public function getHarmonicFrequencies():Array {
			return harmFreqs;
		}				
		
		/*
			Function: getHarmonics
			
			Isolates the harmonics (or partials more generally speaking) of spectral data. The function operates on a
			particular channel pointer in order to extract the partials from the spectrum. getHarmonics populates two
			arrays: harmFreqs and harmAmps which contain the frequencies of the partials and their respective amplitudes
			(in dB). Separate calls are required to retrieve harmAmps (getHarmAmps) and harmFreqs (getHarmFreqs). This
			function must be called before the others to return relevant data.
			
			Results will vary depending on a variety of factors, such as the type of spectrum (noisy or harmonic) as
			well as the hopSize used to process the audio. A harmonic-like spectrum should return the fundamental
			frequency as well as partials that are related by integer multiples of the fundamental (harmonics: i.e.
			110Hz, 220Hz, 440Hz, ...etc). A noisy spectrum will yield non-harmoincally related peaks. Also, a large 
			hopSize will tend to smear the spectral data, since the stationarity assumption does not hold over
			longer time windows.
			
			The C functioncall returns an array indicating 1) if an error was encountered 2) the number of harmonics
			found (may be less than the number requested) 3) the pointer for the amplitude (peaks) array and 4) the
			pointer for the frequency array
			
			Parameters:
				
				desiredHarms - 	An int specifying the desired number of harmonics the function should return. Int value
							   	should be: 0 < desiredHarms < (hopSize/2 + 1)
			
			See Also:
			
				<getHarmonicFrequencies()>,
				<getHarmonicAmplitudes()>
		*/
		
		public function getHarmonics(desiredHarms:uint):void 
		{
			// Clear out contents of old storage arrays....
			harmAmps.splice(0); harmFreqs.splice(0);
			
			// Get the returned object/Array from C....
			var harmArray:Array = lib.getHarmonicsC(chPtrArray[0], desiredHarms);
			var err:int = harmArray[0];						//indicates an error in the algorithmn
			var numHarms:int = harmArray[1];				//the number of harmoincs found
			var peaksPtr:int = harmArray[2];				//the pointer to the amplitude peaks in C memory
			var freqsPtr:int = harmArray[3];				//the pointer to the freq peaks................
			
			// How to access the found harmonics.....
			var peak:Number;
			var freq:Number;
			
			for(var i:int = 0; i < numHarms; i++) {
				cRAM.position = peaksPtr + sizeofFloat*i;
				peak = cRAM.readFloat(); harmAmps.push(peak);
				cRAM.position = freqsPtr + sizeofFloat*i;
				freq = cRAM.readFloat(); harmFreqs.push(freq);
			}
		}		

		/*
			Function: getLPC
			
			Calculates the linear prediction coefficients using Levinson-Durbin recursion.
			
			Parameters:
				
				order - The prediction order.
		*/

		public function getLPC(order:int):Array{
			var lpcArray:Array = lib.getLPCC(chPtrArray[0], order);
			var lpCoefficients:Array = new Array();
			var err:int = lpcArray[0];					//indicates whether or not LPC was executed with (1) or without (0) an error
			var dataPos:int = lpcArray[1];				//the position to start reading the coefficients from
			
			// Access the LP coeffs from memory
			// The last element is the gain
			for (var i:int = 0; i <= (order + 1); i++) {
				cRAM.position = dataPos + sizeofFloat*i;
				lpCoefficients.push(cRAM.readFloat());
			}

			return lpCoefficients;
		}

		/*
			Function: getPitch
			
			Uses the autocorrelation method to estimate the pitch of frame.
			
			Parameters:
				none
			Returns:
				pitch - The estimated pitch value
			
			See Also:
			
				<DSPFunctions.c->autoCorr>
		*/
		public function getPitch():Number {
			var pitch:Number;
			
			pitch = lib.getPitchC(chPtrArray[0]);
			return pitch;
		}

		/*
			Function: getPitchFromSpeech
			
			Same as getPitch except it provides min/max pitch values and a threshold useful for determining if
			there is an active signal in the current frame.
			
			Parameters:
			
				pitchMin - the minimum acceptable pitch value 
				pitchMax - the maximum acceptable pitch value
				intenThreshold - the intensity threshold value
				
			Returns:
				The estimated pitch value

			See Also:
			
				<getPitch()>			
		*/
		
		public function getPitchFromSpeech(pitchMin:Number, pitchMax:Number, intenThreshold:Number):Number {
			
			var estPitch:Number;
			var pitch:Number;
			var inten:Number;

			estPitch = 0;			
			pitch = lib.getPitchC(chPtrArray[0]);
			inten = lib.getIntensityC(chPtrArray[0]);
			
			// Threshold intensity value to see if there is audio present
			if(inten >= intenThreshold) {
				
				//Throw out value if it is not in desired pitch range
				if(pitch >= pitchMin && pitch <= pitchMax) {
					estPitch = pitch;
				} else {
					estPitch = NaN;
				}
			} else {

				// No signal present
				estPitch = NaN;
			}
			
			return estPitch;
		}

		public function getFrequencyResponse(filterArray:Array, gain:Number):Array
		{			
			// Write coeffiecients to C memory
			for(i = 0; i < filterArray.length; i++){
				cRAM.position = filterFIRPtrArray[0] + i*sizeofFloat;
				cRAM.writeFloat(filterArray[i]);
				//trace(filterArray[i]);
			}
			var freqPtrs = lib.getFreqRespC(chPtrArray[0], filterArray.length, gain);
			freqResp = [];

			// Read values	
			for(i = 0; i < freqPtrs[1]; i++){
				cRAM.position = freqPtrs[0] + i*sizeofFloat;
				freqResp.push(cRAM.readFloat());
			}
			return freqResp;
		}
		/* 
			Function: addReverb
			
			This function implements a well-known image model in order to simulate room reverb based on simulated
			room dimensions. A filtering method in the C methods implements a fast-convolution-based filter to add
			the required reverb. The reverb response is calculated based on the emitting-source's position in the
			room, the room's dimensions and the listener (microphone) position. By default the reverb is applied
			to both channels.
			
			Parameters:
			
				activate - 	A String, either "on" or "off". This sets the state of the reverb. Once turned "on", it will remain on
						  	until turned off. If "off", it will remain so until turned on.
				level - A Number value that indicates the reflection strength. Possible values are integers in the range [1-4].
				roomX - the width of the simulated room in the x dimension
				roomY - the width of the simulated room in the y dimension
				roomZ - the height of the simulated room in the z dimension
				srcX - the source (audio) position in the x dimension
				srcY - the source (audio) position in the y dimension
				srcZ - the source (audio) position in the z dimension
				micX - the mic (listener) position in the x dimension
				micY - the mic (listener) position in the y dimension
				micZ - the mic (listener) position in the z dimension
				* all src and mic positions must be within the bounds defined by the 
					simulated room dimensions.
			
		*/
		
		public function addReverb(activate:String, level:Number,
							   roomX:Number, roomY:Number, roomZ:Number,
							   srcX:Number, srcY:Number, srcZ:Number,
							   micX:Number, micY:Number, micZ:Number):void {
			
			for(ch = 0; ch < chPtrArray.length; ch++) {
				var val:int = lib.addReverbC(activate, chPtrArray[ch],
											roomX, roomY, roomZ,
											srcX, srcY, srcZ,
											micX, micY, micZ, level);
			}
		}
		
		/*
			Function: filterAudioFIR
			
			Filters the audio with the given filter (array of coefficients).
			
			Parameters:
			
				filterCoefficients - The filter coefficients.						
		*/		
		public function filterAudioFIR(coeffs:Array):void{
			
			for(ch = 0; ch < numCh; ch++){			
				
				// Write coeffiecients to C memory
				for(i = 0; i < coeffs.length; i++){
					cRAM.position = filterFIRPtrArray[ch] + i*sizeofFloat;
					cRAM.writeFloat(coeffs[i]);
				}
				
				// Filter the audio
				lib.filterAudioFIRC(chPtrArray[ch], coeffs.length);
			}	
		}

		/*
			Function: filterAudioIIR
			
			Filters the audio with the given filter (array of coefficients).
			
			Parameters:
			
			numeratorCoefficients - The numerator coefficients.
			denominatorCoefficients - The denominator coefficients.
		*/		
		public function filterAudioIIR(numCoeffs:Array, denCoeffs:Array, gain:Number):void{
			
			for(ch = 0; ch < numCh; ch++){			
				
				// Write coeffiecients to C memory
				for(i = 0; i < numCoeffs.length; i++){
					cRAM.position = filterFIRPtrArray[ch] + i*sizeofFloat;
					cRAM.writeFloat(numCoeffs[i]);
				}
				for(i = 0; i < denCoeffs.length; i++){
					cRAM.position = filterIIRPtrArray[ch] + i*sizeofFloat;
					cRAM.writeFloat(denCoeffs[i]);
				}
				// Filter the audio
				lib.filterAudioIIRC(chPtrArray[ch], numCoeffs.length, denCoeffs.length, gain);
			}	
		}
		
		/*
			Function: vocoder
			
			Applies the phase vocoder functionality to each AudioChannel object unique to 
			the DATF
			
			Parameters:
			
			active - a boolean value that indicates if the vocoder is on (1) or off(0)
			newPitch - a number (0.5 - 2.0) indicating the factor by which to modify the tempo.
				0.5 correspoinds to an octave up and 2.0 is an octave below.
			newTempo = a number (0.5 - 2.0) indicating the factor by which to modify the the tempo.
				0.5 corresponds to twice the rate and 2.0 corresponds to half the rate.
		*/
		public function vocoder(active:Boolean, newPitch:Number, newTempo:Number) {
			//apply the voocoding to both channels
			
			for(ch = 0; ch < chPtrArray.length; ch++) {
				//trace('channel number ' + chPtrArray[ch] + ' pitch: ' + newPitch + ' tempo ' + newTempo);
				lib.vocodeChannelC(active, chPtrArray[ch], newPitch, newTempo);
			}
		}
								
		/*		
			Group: Utilities
			
			Function: clearAudioBuffers
			
			A Function to clean out the audioBuffers at the completion of audio file playback.

			Notes:
			
			Buffers cleaned are -
				* *inAudioFrame*: A buffer allocated with each channel in C that contains the samples for the current
					frame to be processed and the samples for playback.
				* *Circular Buffers*: A buffer allocated with each channel that tracks overlapping audio samples when
					certain operations (i.e. filtering) are in use.
			
			See Also:
			
			<AudioChannel.cpp>, <ALF.stopAudio()>
		*/
		
		public function clearAudioBuffers():void{
			
			for(ch = 0; ch < numCh; ch++){
				lib.clearAudioFrameC(chPtrArray[ch]);		//clears audioFrame (where we read/write audio to)
				lib.clearAudioBufferC(chPtrArray[ch]);		//clears circularBuffers  (for filtering sequences)
				
			}
		}
		
		
	
		/*		
			Function: checkOutputBuffer
		
			A function to determine if the C-based audioFrame is ready for reading during audio playback.
			
			Parameters:
				channelType - A string indicating the desired channel to be checked. "left" and "right" are valid
					arguments.
					
			Returns:
				An array containing 
				
				* 1) A boolean indicating whether or not the audio is ready for playback and 
				* 2) The number of samples that can be played if the status is "true" (i.e. its ready).
		*/
		
		public function checkOutputBuffer(channelType:String):Array {
			var bufferStatus:Array;
			switch(channelType) {
				case "left":
							//trace('checking left audio buffer');
							bufferStatus = lib.checkOutputBufferC(chPtrArray[0]);
							break;
				case "right":
							//trace('checking right audio buffer');
							bufferStatus = lib.checkOutputBufferC(chPtrArray[1]);
							break;
				default:
							trace('invalid channel type');
			}
			
			return bufferStatus;
			
		}
		/*
			Function: endOfFile()
			
			This function should be called when a file is complete or after <ALF.stopAudio> has been called. The 
			buffers are cleared, flags reset, and parameters in the AudioChannel set accordingly to begin playback
			of the beginning of a file.
			
			See Also:
			
			<AudioChannel.cpp>, <ALF>
			
		*/
		public function endOfFile():void{
			
			for(ch = 0; ch < numCh; ch++){
				lib.resetAllC(chPtrArray[ch]);
			}			
		}	

		/*
			Function: getChOutPtrs()
			
			Returns: An array containing the pointers to the C audio buffers. The first element is the left channel pointer, the second element is the right channel.
			Note these pointers are different from what is returned by <getCRAM()> in that they provide the location of the current sample in the audio buffers where as 
			getCRAM() provides a pointer to the entire shared C memory buffer which includes all variables instantiated in <ALFPackace.cpp>.
			
			
		*/
		public function getChOutPtrs():Array {
			// Returns reference to array containing channel audio pointers so we can read directly from those buffers
			// for audio output
			return chOutArray;
		}
		
		/*
			Function: getCRAM()
			
			Returns: A pointer to the C memory buffer.
			
		*/				
		public function getCRAM():ByteArray {
			
			// Reference to the shared cRAM memory
			return cRAM;
		}
		
		/*
			Function: getHopSize()
			
			Returns:
			
			The current hopSize in the DATF.
			
		*/
		public function getHopSize():uint{
			return hopSize;
		}			
		
		/*
			Function: getNumberOfChannels()
			
			Returns:
			
			The current number of channels.
			
		*/
		public function getNumberOfChannels():uint{
			return numCh;
		}							
		/*
			Function: reInitializeChannel
			
			This funciton should be called when a new song is loaded with a different sample rate(for wav) or the 
			hop size is changed. This equates to a change in the number of frames per second. It will create a 
			right channel if one does not exist.
			
			Parameters:
			
				hop - The new hop size.
				sampleRate - The new sample rate.
				channels - The number of channels in the new song.
				frameLookAhead - The offset (in frames) between the current data being returned and audio playback.	
				
			See Also:
			
				<AudioChannel.cpp->reInitChannel>, <ALFPackage.cpp->reInitializeChannel>
		*/
		public function reInitializeChannel(hop:uint, sampleRate:uint, channels:Number, frameLookAhead:Number):void{

			// Save new parameters as globals
			hopSize = hop;
			fs = sampleRate;
			numCh = channels;
			
			var newPtrs:Array = new Array();
			
			for(ch = 0; ch < numCh; ch++){
				
				// If the right channel does not exist, create it.
				if(chPtrArray[ch] == null){
				
					rightCh = new Array();	
					rightCh = lib.initAudioChannelC("rightCh", fs, hopSize, frameLookAhead);			
					chPtrArray.push(rightCh[0]);
					chInArray.push(rightCh[1]);
					chOutArray.push(rightCh[2]);
					chSamplesPtrArray.push(rightCh[3]);
					filterFIRPtrArray.push(rightCh[4]);
					filterIIRPtrArray.push(rightCh[5]);
				}else{
					
					// Reinitialize the channel
					lib.reInitializeChannelC(chPtrArray[ch], hop, sampleRate, numCh, frameLookAhead);
					newPtrs = lib.getInAudioPtrC(chPtrArray[ch]);
					chInArray[ch] = newPtrs[0];					
				}
				
			}			
		}
		
		/*
			Function: resetAll
			
			This resets all of the buffers and values to their state at initialization.
			
			See Also:
			
			<ALFPackage.cpp->resetAll>
		*/
		public function resetAll():void{
			
			for(ch = 0; ch < numCh; ch++){
				lib.resetAllC(chPtrArray[ch]);
			}
		}
	}
}