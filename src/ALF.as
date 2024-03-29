﻿/*
   Copyright 2009 Music and Entertainment Technology Laboratory - Drexel University
   
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at:

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/


package{
	
	import flash.utils.ByteArray;
	import flash.events.SampleDataEvent;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.media.Sound;
	import flash.media.SoundChannel;	
	import flash.net.*;
	import flash.events.Event;
	import flash.utils.Endian;
	import flash.events.IOErrorEvent;
	import flash.events.EventDispatcher;
	import flash.utils.*;
	import DATF;
	
	/*
		Class: ALF.as
		
		The Audio processing Library for Flash. ALF plays an audio file (MP3 or wav) using the dynamic audio functionality 
		of Actionscript3 and provides methods for obtaining audio features and manipulating the audio output stream on a frame by frame basis.
	*/
	public class ALF extends EventDispatcher{
		
		// Sound playback		
		private var audio:Sound;
		private var mp3Audio:Sound;
		private var audioCh:SoundChannel;
		private var mp3Bytes:ByteArray;
		private var playBytes:ByteArray;
		private var loadedData:URLLoader;
		public var numCh:uint;
		public var fs:uint;
		public var trackName:String;
		private var leftSample:Number;
		private var rightSample:Number;		
		private var mp3Position:uint = 0;
		private var wavPosition:uint;
		private var fileExt:String;				
		private var waveLoader:URLLoader;
		private var mp3Loader:URLLoader;
		private var STEREO:Boolean = false;
		private var READY:Boolean = false;
		public var STOP:Boolean = false;  //made this public so the calling script can figure out if audio is playing
		private var CONTINUE:Boolean = false;
		
		// variables needed for determining the duration and position in audio
		public var duration:Number;
		public var bytesPerSample:int;
		
		public var startTime:uint;	// user specified playback position of the track (in msec)
		
		public var ITER:uint= 0;
		public var LOAD_COUNT:uint = 0;
		
		// Framing
		public var chVal:Number;
		public var numSamplesToPlay:Number;
		private var userFrameRate:uint = 0;
		public var frameSize:uint = 4096;
		public var hopSize:uint = 2048;
		private var LOOK_AHEAD:Boolean = false;
		private var frameLookAhead:Number;

		// DATF
		private var DSP:DATF;
		
		//C Memory stuff
		private var cRAM:ByteArray;
		private var audioPtrs:Array;
		private const sizeofFloat:Number = 4;
		
		//Buffer Status vars
		private var leftBufferStatus:Array;
		private	var rightBufferStatus:Array;
		private	var numSamplesLeft:int;
		private var numSamplesRight:int;
		
		// Events
		public const NEW_FRAME:String = "newFrame";
		public const FILE_LOADED:String = "audioFileLoaded";
		public const FILE_COMPLETE:String = "audioFileCompleted";
		public const PROG_EVENT:String = "newProgressEvent";
		public const URL_ERROR:String = "urlErrorEvent";
		
		// Utility
		private var i:uint;
		private var tempInt:int;	
		private var tempNum:Number;
		private var verbose:Boolean;
		public var loadProgress:Number;		// publicly available so audio file-loading can be monitored from outside of the class
		private var INITIALIZED:Boolean = false;
		
		// Features
		public var inten:Number, cent:Number, band:Number, roll:Number, flux:Number, pitchVal:Number;
		public var harmAmps:Array, harmFreqs:Array, magArr:Array, fftArr:Array, lpcArray:Array, freqResp:Array;

		/*		
				
			Topic: Usage
			
			ALF is a library whose functions return audio features and perform other operations on an audio file on a frame-by-frame basis. 
			In this current version, an event, NEW_FRAME, is dispatched whenever a new audio frame begins. To synchronize 
			visual events with audio, use NEW_FRAME as you might use onEnterFrame (AS event that signals a new frame in the 
			timeline). 
			
			We recommend using the event NEW_FRAME rather than onEnterFrame since these events are not guaranteed to be synchronized. Applications
			can still use onEnterFrame, but the calls to ALF should be done using the NEW_FRAME event. In this case, unique values may not be 
			returned every frame since the onEnterFrame runs in parallel with the NEW_FRAME callback and has no dependency.
			A simple example that plays a file and plots a feature is shown below:
			
			Topic: Example
			
			This is a simple example that loads an audio file into ALF and then plots one of the audio features as the song plays with a 
			look-ahead of 20 frames. For visual applications the frame look-ahead is implemented so that the developer has some foreknowledge
			of events before they happen (i.e. large changes can be transitioned smoothly). 
			
			The	values are calculated in real time and then displayed on the stage. On each frame, a line segment is drawn from the feature
			value of the previous frame to the feature value of the current frame. 
			
			(start code)
			package{
				
				import flash.display.MovieClip;
				import flash.events.*;
				import flash.display.Graphics;
				import flash.geom.ColorTransform;
			
				public class ALFDemo extends MovieClip{
						
					private var myALF:ALF;
					
					private var intensity:Number;
					
					// Display
					var vidFrame:uint = 0;
					var line:MovieClip;
					var line2:MovieClip;
					var colorChange:ColorTransform;
					var lineArr:Array;
					var xCoord:uint = 0;		
					var val:Number;
					
					// Utilities
					var i:uint = 0;
					var count:uint = 0;
					var frameCount:uint = 1;
					var alfCount:Number = 1;
					var offset:uint = 2;		
					
					
					
					public function ALFDemo(){
						
						// Define audio file, use this example file or specify the path (local or server) of your own file
						var str:String;
						str = 'http://music.ece.drexel.edu/~jscott/speech_dft.mp3';
			
						// Create ALF object
						myALF = new ALF(str, 0, 30, false, 20);						// 30 fps with 20 frame look-ahead 
						myALF.addEventListener(myALF.NEW_FRAME, onFrame);			// Audio callback (ALF functions should be called in this handler)
						myALF.addEventListener(myALF.FILE_LOADED, audioLoaded);		// Adds listener for when the audio data has loaded
						myALF.addEventListener(myALF.FILE_COMPLETE, audioFinished);	// Event for when the file has fiished playing				
						
						// Initialize objects for drawing
						lineArr = new Array();
						line = new MovieClip();
						lineArr.push(line);
						line.graphics.lineStyle( 1, 0xFF0000, 1000);
						line.graphics.moveTo(0, 400);
						addChild(line);			
					}
			
					// This handles the event that ALF dispatches for each audio frame. If your video frame rate is
					// the same, you should have synchronicity between your audio feature values and your video frames,
					// that is, there should be no lag or offset between the value calculated and the audio that is playing.							
					public function onFrame(event:Event):void{
						
						intensity = myALF.getIntensity();
					
						// Clear screen if reached border
						if(xCoord > 550){
			
							for(i = 0; i < lineArr.length; i++){
								lineArr[i].graphics.clear();
							}
							line.graphics.moveTo(offset, 400);
							xCoord = 0;
						}
												
						if(frameCount > offset){			
							
							// Draw line					
							val = intensity/10
							if(isNaN(val)){ val = 0;} 
							line.graphics.lineStyle( 1, 0xFF0000, 1000);
							line.graphics.lineTo(xCoord, 400 - val);			
							addChild(line);				
								
							// Set up for draw on next frame
							line = new MovieClip();
							lineArr.push(line);
							line.graphics.moveTo(xCoord, 400 - val);				
						}
						
						frameCount++;
						xCoord = xCoord + 3;			
					}	
					
					
					// This funciton is called when the audio has been loaded in ALF and the FILE_LOADED event has been dispatched
					public function audioLoaded(event:Event):void{
												
						myALF.startAudio();
						trace('playing audio ...');
					}		
					
					// This funciton is called when the audio has finished playing and the FILE_COMPLETE event has been dispatched
					public function audioFinished(event:Event):void{
						
						trace('audioFinished'); 
						trace('---------------------------------------');
					}
				}
			}
			(end)		
		
		*/

		/*
			Group: Constructor
			
			Constructor: ALF
			
			Constructor for ALF.
			
			Parameters:
			
				filename - The filename of the audio file to play. This must be a .wav or .mp3 file.
				_startTime - An Int the range (0 - duration) specifying where playback should begin in the audio file. Start
				time is represented in milliseconds (1msec = 0.001 seconds)
				framesPerSecond - The frame rate in frames per second. Values between 10 and 40 fps are currently supported. 
				_verbose - When true, prints the .wav file header in the output window. The header contains information such as the 
						   sample rate, bit rate, number of channels, size, etc. This parameter does not effect mp3 files.
				
			Notes:
			
				The frame rate that audio is processed at is based on the NEW_FRAME (<ALF Events>) event. Make sure to set the frame 
				rate of your .fla file to the same rate you enter as the framesPerSecond parameter if you want good synchronization 
				between audio and video.
				
				Currently ALF does not have a default destructor method to free the associated memory when you're done with it. Rather,
				ALF's should be re-used. This can be accomplished simply by calling the loadNewSong method and passing the 
				appropriate string for the new audio file as an argument.

		*/
		public function ALF(filename:String, _startTime:uint, framesPerSecond:uint, _verbose:Boolean, _frameLookAhead:Number){
		
			if(frameLookAhead > 0) LOOK_AHEAD = true;
			
			// Save parameter values
			verbose = _verbose;
			frameLookAhead = _frameLookAhead;			
			startTime = _startTime;
			
			//parse off the track name so we can save that as an ALF property
			trackName = filename;
			var res:Array = trackName.split('/');
			trackName = res[res.length - 1];
		
			// FrameSize is set after the sound file has been loaded in
			userFrameRate = framesPerSecond;
			trace('fps = '+userFrameRate);		
			
			// Initialize the sound objects
			audio = new Sound();
			audioCh = new SoundChannel();			
			
			// Find file extension
			fileExt = filename.substr(filename.length - 3, 4);
			fileExt = fileExt.toLowerCase();

			switch(fileExt){
				
				case "wav": 	// Initialize wav objects
								waveLoader = new URLLoader();											// Initialize URL Looader							
								waveLoader.dataFormat = URLLoaderDataFormat.BINARY;						// Set to binary format
								waveLoader.addEventListener(Event.COMPLETE, waveLoaded);				// Event for when file is loaded
								waveLoader.addEventListener(ProgressEvent.PROGRESS, waveProgress);		// Event for getting file loading data
								waveLoader.addEventListener(IOErrorEvent.IO_ERROR, waveLoadError);		// Event for file loading erros
								audio.addEventListener(SampleDataEvent.SAMPLE_DATA, wavAudioCallback); 	// Add event for each audio frame
								var waveRequest:URLRequest = new URLRequest(filename);					// Set filename to load
					
								// Attempting to read in the wave file
								waveLoader.load(waveRequest);

								break;
				
				case "mp3":		// Initialize mp3 objects
								var mp3Request:URLRequest = new URLRequest(filename);					// Load filename
								mp3Bytes = new ByteArray();												// For raw samples from file								
								mp3Bytes.endian = Endian.LITTLE_ENDIAN;									// Set endianess for data processed in CPP
								playBytes = new ByteArray();											// For playback of endian converted samples
								playBytes.endian = Endian.BIG_ENDIAN;									// Set endianess for playback in Flash
								
								mp3Audio = new Sound();													// Sound object for audio file
								STEREO = true;
								fs = 44100;
								
								// Attempting to read in the MP3 file
								mp3Audio.addEventListener(IOErrorEvent.IO_ERROR, mp3LoadError);			// Handle failed load
								mp3Audio.addEventListener(Event.COMPLETE, mp3Loaded);					// Dispatched when file is loaded	
								mp3Audio.addEventListener(ProgressEvent.PROGRESS, mp3Progress);
								mp3Audio.load(mp3Request);											
								audio.addEventListener(SampleDataEvent.SAMPLE_DATA, mp3AudioCallback); 	// Dispatched on each audio frame				
								
								break;
				
				default:		trace('Invalid file type! ALF only supports .wav and .mp3 files');
			}					
			trace('loaded in the audio file....');
		}
		
		// These functions notify the user of an error in loading the audio file
		private function mp3LoadError(error:IOErrorEvent):void{
			trace('Error loading mp3: '+error);
			dispatchEvent(new Event(URL_ERROR));
		}
		
		private function waveLoadError(error:IOErrorEvent):void{
			trace('Error loading wav file: '+error);
			dispatchEvent(new Event(URL_ERROR));
		}		

		/******************************************************************************
		*
		*							AUDIO PLAYBACK FUNCTIONS
		*
		******************************************************************************/		
		
		// This is an internal function to play the current file again automatically when the end of the file is reached.
		// If the boolean CONTINUE is true, then the file will loop, if it is false, the file will only be played once.
		private function continueAudio():void{
			
			switch(fileExt){
				
				case 	"wav": 	loadedData.data.position = 44;										// Reset to beginning of file
								audioCh = audio.play();												// Start playback
								audioCh.addEventListener(Event.SOUND_COMPLETE, audioComplete);
								break;
						
				case	"mp3":	mp3Position = 0;													// Reset to beginning of file 
								mp3Bytes.length = 0;												// Reset byte array
								mp3Position += mp3Audio.extract(mp3Bytes, hopSize, mp3Position);	// Extract audio
								audioCh = audio.play();												// Start playback
								audioCh.addEventListener(Event.SOUND_COMPLETE, audioComplete);		
								break;
			}
			
		}		

		/*
			Group: Audio Playback	
			
			Function: loadNewSong
			
			Use this function to load a new file into ALF for processing and playback.
			
			Parameters:
			
			filename - The filename (.wav or .mp3) of the audio file to be played. A new FILE_LOADED event will be dispatched
					   when the file has finished loading.
			_startTime - specifies the offset (in msec) where playback should start in the track
		*/
		public function loadNewSong(filename:String, _startTime:uint):void{
			
			startTime = _startTime;
			
			// Sets the flag that this is a new file being loaded
			DSP.endOfFile();

			// Re-initialize the sound objects
			audio = null;
			audioCh = null;
			audio = new Sound();
			audioCh = new SoundChannel();			
						
			// Find file extension
			fileExt = filename.substr(filename.length - 3, 4);
			fileExt = fileExt.toLowerCase();			
			
			switch(fileExt){
				
				case "wav": 	// Initialize wav objects
								waveLoader = null;
								waveLoader = new URLLoader();											// Initialize URL Looader							
								waveLoader.dataFormat = URLLoaderDataFormat.BINARY;						// Set to binary format
								waveLoader.addEventListener(Event.COMPLETE, waveLoaded);				// Event for when file is loaded
								waveLoader.addEventListener(ProgressEvent.PROGRESS, waveProgress);		// Event for getting file loading data
								waveLoader.addEventListener(IOErrorEvent.IO_ERROR, waveLoadError);		// Event for file loading erros
								audio.addEventListener(SampleDataEvent.SAMPLE_DATA, wavAudioCallback); 	// Add event for each audio frame
								var waveRequest:URLRequest = new URLRequest(filename);					// Set filename to load
					
								// Attempting to read in the wave file
								waveLoader.load(waveRequest);

								break;
				
				case "mp3":		// Initialize mp3 objects
								var mp3Request:URLRequest = new URLRequest(filename);					// Load filename
								mp3Bytes = new ByteArray();												// For raw samples from file								
								mp3Bytes.endian = Endian.LITTLE_ENDIAN;									// Set endianess for data processed in CPP
								playBytes = new ByteArray();											// For playback of endian converted samples
								playBytes.endian = Endian.BIG_ENDIAN;									// Set endianess for playback in Flash
								
								mp3Audio = new Sound();													// Sound object for audio file
								STEREO = true;
								fs = 44100;
								
								// Attempting to read in the MP3 file
								mp3Audio.addEventListener(IOErrorEvent.IO_ERROR, mp3LoadError);			// Handle failed load
								mp3Audio.addEventListener(Event.COMPLETE, mp3Loaded);					// Dispatched when file is loaded	
								mp3Audio.addEventListener(ProgressEvent.PROGRESS, mp3Progress);
								mp3Audio.load(mp3Request);											
								audio.addEventListener(SampleDataEvent.SAMPLE_DATA, mp3AudioCallback); 	// Dispatched on each audio frame				
								
								break;
				
				default:		trace('Invalid file type! ALF only supports .wav and .mp3 files');
			}			
			
			
		}
		
		/*		
			Function: startAudio
			
			A function to begin playback of an audio file. The FILE_LOADED event (<ALF Events>) must have been dispatched 
			and received by the class instantiating ALF prior to calling startAudio. Use startAudio to resume playback after
			calling pauseAudio.
			
			See Also:
		
				<stopAudio()>,
				<pauseAudio()>,
				<Example>
		*/
		public function startAudio():void{ 
								
			// When audio has already been played then stopped.
			if(READY && STOP){
				
				switch(fileExt){
					
					case 	"wav":  audioCh = audio.play();
									audio.addEventListener(SampleDataEvent.SAMPLE_DATA, wavAudioCallback);									
									audioCh.addEventListener(Event.SOUND_COMPLETE, audioComplete);
									break;
							
					case	"mp3":	audioCh = audio.play();
									audio.addEventListener(SampleDataEvent.SAMPLE_DATA, mp3AudioCallback);									
									audioCh.addEventListener(Event.SOUND_COMPLETE, audioComplete);
									break;
				}								
				
			}

			// First time being played or continuing after a pause 
			else if (READY){ 
				audioCh = audio.play();
				audioCh.addEventListener(Event.SOUND_COMPLETE, audioComplete);
				
			}else if(!READY){
				trace('ALF not initialized. Do not call startAudio() until file has loaded.');
			}
			
			STOP = false;
		}
		
		/*
			Function: pauseAudio
			
			A function to pause playback of an audio file. To resume playback, use startAudio.
			
			See Also:
		
				<startAudio()>,
				<stopAudio()>
		*/
		
		public function pauseAudio():void{
			audioCh.stop();			
		}
		
		/*
			Function: stopAudio
			
			A function to stop playback of an audio file. This function removes the SampleDataEvent associated with the audio object. 
			The object will no longer call for more data to playback. Note that the SOUND_COMPLETE event will not be dispatched if
			this function is called. When startAudio is called after stopAudio, the current file loaded will play from the beginning.
			
			See Also:
		
				<startAudio()>,
				<pauseAudio()>,
				<Example>
		*/
		public function stopAudio():void{
			
			//DSP.clearAudioBuffers();
			DSP.endOfFile();
			
			switch(fileExt){
				
				case 	"wav":  audioCh.stop();							// Stopping playback								
								loadedData.data.position = 44;			// Reset to beginning of file
								
								break;
						
				case	"mp3":	audioCh.stop();							// Stopping playback											
								mp3Bytes.length = 0;					// Reset ByteArray
								mp3Position = 0;						// Reset to beginning of file
								mp3Position += mp3Audio.extract(mp3Bytes, hopSize*2, mp3Position);
								
								break;
			}
			
			STOP = true;
		}				

		/******************************************************************************
		*
		*									EVENTS		
		*
		*******************************************************************************/

		// These functions dispatch the PROG_EVENT to monitor the progress of a file 
		// being loaded. View the documentation for more information.
		private function waveProgress(evt:ProgressEvent):void {
			loadProgress = evt.bytesLoaded/evt.bytesTotal;
			dispatchEvent(new Event(PROG_EVENT));
		}
		private function mp3Progress(evt:ProgressEvent):void {
			loadProgress = evt.bytesLoaded/evt.bytesTotal;
			dispatchEvent(new Event(PROG_EVENT));
		}		
	
		// This function initializes sets all parameters in the C Library 
		private function waveLoaded(evt:Event):void {
			
			loadedData = URLLoader(evt.target);		// Establishing reference to object containing data read in from URLRequest
			extractWaveHeader(loadedData);			// Extract wave file header		
			
			// Need to set the frameSize based on desired userFrameRate and fs from the audio
			if(userFrameRate > 40 || userFrameRate < 10){
				trace("Invalid user-selected frame rate. Valid frame rates are between 10fps and 40fps.");
				trace("Defaulting to 10fps");
				hopSize = 1024;
			}else {
				hopSize = Math.round(fs/userFrameRate);
			}	
			frameSize = 2*hopSize;					
			
			// If this is the first file loaded into the DATF, we use the constructor, if not we must call reInitializeChannel.
			// The program will crash if you attempt to create a new DATF after already having created one.
			if(!INITIALIZED){
				
				// Initialize the DATF
				DSP = new DATF(hopSize, STEREO, fs, frameLookAhead);		
				DSP.addEventListener(DSP.PROCESS_FRAME, processFrameHandler);				

				// Get the Reference to the cRAM data
				cRAM = DSP.getCRAM();
				audioPtrs = DSP.getChOutPtrs();
				
				INITIALIZED = true;
			}else{
				
				// Re-initializing the channel changes the frame sizes based on the new sampling rate and reallocates
				// C memory accordingly
				if(DSP.getHopSize() != hopSize || numCh != DSP.getNumberOfChannels()){		
					DSP.reInitializeChannel(hopSize, fs, numCh, frameLookAhead);		// New hopSize and fs are set in extractWaveHeader().
				}

			}
			
			// Set ready for playback flag
			READY = true;
			dispatchEvent(new Event(FILE_LOADED));
			
			// If the user wishes to begin playback from a different point other than the beginning of the track
			// we need to adjust the starting position accordingly
			
			if(startTime < 0 || (startTime/1000) > duration) {
				trace('an invalid starting position was specified! playing from the beginning of the track ');
				startTime = 0;
			}
			
			var startPosSamples:int = (startTime/1000)*fs;
			var startPosBytes:int = startPosSamples*bytesPerSample;
			
			//adjust the position to reflect the shift in start position
			loadedData.data.position = loadedData.data.position + startPosBytes;
		}

		// This function initializes all parameters in the C Library 
		private function mp3Loaded(evt:Event):void{
			
			// Stereo
			numCh = 2;
			STEREO = true;
			
			// Need to set the hopSize based on desired userFrameRate and fs from the audio
			if(userFrameRate > 40 || userFrameRate < 10){
				trace("Invalid user-selected frame rate. Valid frame rates are between 10fps and 40fps.");
				trace("Defaulting to 10fps");
				hopSize = 1024;
			}else {
				hopSize = Math.round(fs/userFrameRate);
			}	
			
			frameSize = 2*hopSize;

			// If this is the first file loaded into the DATF, we use the constructor, if not we must call reInitializeChannel.
			// The program will crash if you attempt to create a new DATF.
			if(!INITIALIZED){

				// Initialize the DATF
				DSP = new DATF(hopSize, STEREO, fs, frameLookAhead);		
				DSP.addEventListener(DSP.PROCESS_FRAME, processFrameHandler);				

				// Get the Reference to the cRAM data
				cRAM = DSP.getCRAM();
				audioPtrs = DSP.getChOutPtrs();
				
				INITIALIZED = true;
			}else{
				
				// Re-initializing the channel changes the frame sizes based on the new sampling rate and reallocates
				// C memory accordingly								
				mp3Bytes.length = 0; 
				if(DSP.getHopSize() != hopSize || DSP.getNumberOfChannels() != numCh){
					DSP.reInitializeChannel(hopSize, fs, numCh, frameLookAhead);
				}												
			}
			
			// determine what sample the user wants to start at.
			if(startTime < 0 || (startTime/1000) > duration) {
				trace('an invalid starting position was specified! ...playing from the beginning of the track ');
				startTime = 0;
			}
			
			var startPosSamples:int = (startTime/1000)*fs;

			// Extract samples of first frame and specify the offset
			mp3Bytes.position = 0;
			mp3Position = startPosSamples;  // mp3's position works off of samples, not bytes
			mp3Position += mp3Audio.extract(mp3Bytes, frameSize, mp3Position);						
			
			trace('ALF new song: fs = ' +fs, 'numCh = ' +numCh);
			//Set ready for playback flag
			READY = true;
			dispatchEvent(new Event(FILE_LOADED));
		}

		
		// Dispatches the NEW_FRAME event
		public function processFrameHandler(event:Event):void{
			dispatchEvent(new Event(NEW_FRAME));			
		}
				

		// Called when the file has completed
		private function audioComplete(evt:Event):void{
			
			// At end of file reset buffers/flags
			DSP.endOfFile();
			
			if(CONTINUE){
				continueAudio();				
			}else{
				switch(fileExt){
					
					case "wav":	loadedData.data.position = 44; 											// Reset to beginning of file
								break;
								
					case "mp3": mp3Bytes.length = 0;													// Reset ByteArray
								mp3Position = 0;														// Reset to beginning of file
								mp3Position += mp3Audio.extract(mp3Bytes, hopSize*2, mp3Position);		// Extract samples															
								break;
				}
			}
			STOP = true;
			dispatchEvent(new Event(FILE_COMPLETE));	// Event to tell user file has finished
		}
						
		// Plays wav audio samples
		private function wavAudioCallback(evt:SampleDataEvent):void {
			
			var bufferReady:Boolean = false;
			
			// As long as there is data left to read into C...we read it in and process the data
			// by dispatching a new event.
			var channelReady = 0;
			if(loadedData.data.bytesAvailable != 0){
				channelReady = DSP.setFrame(loadedData.data, "short");
			}else {}
			
			// Check the status of the buffers to see if they're ready for playback....
			leftBufferStatus = DSP.checkOutputBuffer("left");
			numSamplesToPlay = leftBufferStatus[1];
			bufferReady = leftBufferStatus[0];
			if(STEREO) {
				rightBufferStatus  = DSP.checkOutputBuffer("right");	
				numSamplesToPlay = Math.min(leftBufferStatus[1], rightBufferStatus[1]);	
				if(rightBufferStatus[0] && leftBufferStatus[0]) {
					bufferReady = true;
				} else 	{
					bufferReady = false;
				}
			}

			// If not ready for playback, load another frame and check again
			while(!bufferReady){
				
				channelReady = 0;
				if(loadedData.data.bytesAvailable != 0){
					channelReady = DSP.setFrame(loadedData.data, "short");
				} else {}
				
				leftBufferStatus = DSP.checkOutputBuffer("left");
				numSamplesToPlay = leftBufferStatus[1];
				bufferReady = leftBufferStatus[0];
				if(STEREO) {
					rightBufferStatus  = DSP.checkOutputBuffer("right");	
					numSamplesToPlay = Math.min(leftBufferStatus[1], rightBufferStatus[1]);	
					if(rightBufferStatus[0] && leftBufferStatus[0]) {
						bufferReady = true;
					} else {
						bufferReady = false;
					}
				}

			}

			// Play the samples
			if(STEREO){
				
				switch(fs){
					
					case 44100:		for(i = 0; i < numSamplesToPlay; i++){
										
										cRAM.position = audioPtrs[0] + i*sizeofFloat;		//position for leftCh
										leftSample = cRAM.readFloat();
										cRAM.position = audioPtrs[1] + i*sizeofFloat;		//position for rightCh
										rightSample = cRAM.readFloat();
										
										// Write to output stream
										evt.data.writeFloat(leftSample);
										evt.data.writeFloat(rightSample);
									}
									break;
									
					case 22050:		for(i = 0; i < numSamplesToPlay; i++){
										
										cRAM.position = audioPtrs[0] + i*sizeofFloat;		//position for leftCh
										leftSample = cRAM.readFloat();
										cRAM.position = audioPtrs[1] + i*sizeofFloat;		//position for rightCh
										rightSample = cRAM.readFloat();
										
										// Write to output stream
										evt.data.writeFloat(leftSample);
										evt.data.writeFloat(rightSample);
										evt.data.writeFloat(0);
										evt.data.writeFloat(0);
									}
				}

			}else if (!STEREO){
				
				switch(fs){
					
					case 44100: 	for(i = 0; i < numSamplesToPlay; i++){
										
										cRAM.position = audioPtrs[0] + i*sizeofFloat;		//position for leftCh
										leftSample = cRAM.readFloat();
										
										// Write to output stream
										evt.data.writeFloat(leftSample);
										evt.data.writeFloat(leftSample);
									}
									break;
									
					case 22050:		for(i = 0; i < numSamplesToPlay; i++){
										
										cRAM.position = audioPtrs[0] + i*sizeofFloat;		//position for leftCh
										leftSample = cRAM.readFloat();
										
										// Write to output stream
										evt.data.writeFloat(leftSample);
										evt.data.writeFloat(leftSample);
										evt.data.writeFloat(0);
										evt.data.writeFloat(0);
									}
									break;
				}

			}else{
				trace('ERROR: ALF can only handle mono or stereo files.');
			}
		}
		
		// Plays mp3 audio samples
		private function mp3AudioCallback(evt:SampleDataEvent):void {
			
			var bufferReady:Boolean = false;			
			
			// As long as there is data left to read into C...we do that and process the data
			// by dispatching a new event (in DATF)
			var channelReady = 0;

			mp3Bytes.position = 0;
			if(mp3Bytes.length > 0){					
				channelReady = DSP.setFrame(mp3Bytes, "float");
			}													
			
			// Check the status of the buffers to see if they're ready for playback....
			leftBufferStatus = DSP.checkOutputBuffer("left");
			rightBufferStatus  = DSP.checkOutputBuffer("right");									
			numSamplesToPlay = Math.min(leftBufferStatus[1], rightBufferStatus[1]);	
			
			if(rightBufferStatus[0] && leftBufferStatus[0]){ 
				bufferReady = true;
			}
			
			// Extract audio data from sound object If the inBuffer was not ready, we have not written data to C/C++ and 
			// consequently do not want to extract new data.
			if(channelReady != 0){
				mp3Bytes.length = 0;			
				mp3Position += mp3Audio.extract(mp3Bytes, hopSize, mp3Position);			// Extract samples					
			}
			
			// If not ready for playback, load another frame and check again
			while(!bufferReady){
				
				channelReady = 0;
				mp3Bytes.position = 0;
				if(mp3Bytes.length > 0){									
					channelReady = DSP.setFrame(mp3Bytes, "float");	
				}			
				//trace('channelReady = ' +channelReady);
				
				// Check the status of the buffers to see if they're ready for playback....
				leftBufferStatus = DSP.checkOutputBuffer("left");
				rightBufferStatus  = DSP.checkOutputBuffer("right");									
				numSamplesToPlay = Math.min(leftBufferStatus[1], rightBufferStatus[1]);	
				
				if(rightBufferStatus[0] && leftBufferStatus[0]) {
					bufferReady = true;
				} else {
					bufferReady = false;
				}
					
				// Extract audio data from sound object. If the inBuffer was not ready, we have not written data to C/C++ and 
				// consequently do not want to extract new data.
				if(channelReady != 0){
					mp3Bytes.length = 0;			
					mp3Position += mp3Audio.extract(mp3Bytes, hopSize, mp3Position);	
				}

			}			

			for(i = 0; i < numSamplesToPlay; i++){
										
				cRAM.position = audioPtrs[0] + i*sizeofFloat;		//position for leftCh
				leftSample = cRAM.readFloat();
				cRAM.position = audioPtrs[1] + i*sizeofFloat;		//position for rightCh
				rightSample = cRAM.readFloat();
								
				// Write samples
				evt.data.writeFloat(leftSample);
				evt.data.writeFloat(rightSample);
			}				
			
		}
		
		/******************************************************************************
		*
		*						  DSP FUNCTIONS
		*	
		******************************************************************************/			
		/*			
			Group: Audio Features
			
			Values returned from all features are dependent upon the input audio. The style, genre, 
			and instrumentation play a significant role in 	the numbers returned from each function 
			but the production value (i.e. compression/mastering) also weighs heavily into what range
			of values is returned, especially for the intensity.
			
			Function: getIntensity
			
			This function calculates the intensity of the current audio frame loaded into ALF. The 
			intensity is a measure of how much energy is in the current	frame. If there are many 
			instruments playing loudly, this value will be large, for an ambient section of a song,
			this value will be smaller.
			
			Returns:
				
				An Number which is the intensity value for the current frame. The range of values 
				will be dependent mostly upon the production value of the audio file. 
				
		*/		
		public function getIntensity():Number{
			
			inten = DSP.getIntensity();
			return inten;
		}
		
		/*

			Function: getBrightness

			Brightness is an approximation of the timbre. If there is high frequency content, such as
			a horn section, then the brightness is higher, for low frequency, such as drum and bass, the
			brightness value will be lower.
			
			Returns:
			
			A Number which is the brightness (in Hz) value for the current frame. Typical values will 
			be around several thousand hertz. 

		*/		
		public function getBrightness():Number{
			
			cent = DSP.getCentroid();
			return cent;
		}		
		
		/*
			Function: getFlux

			This function calculates the change in frequency content for each frame. Instantaneous changes in 
			the audio content (both new sounds and sudden quiet) will produce large flux values.
			
			Returns:
			
			A Number which is the flux value for the current frame.

		*/		
		public function getFlux():Number{
			
			flux = DSP.getFlux();
			return flux;
		}				
		
		/*
			Function: getBandwidth
		
			This function calculates the bandwidth of the current audio frame loaded into ALF. The 
			bandwidth represents the range of frequencies present in the audio at the current frame.
			This value gives an estimate of the instrumentation. A full band with drums, vocals, keys,
			bass, guitar, synth, etc. will have a large bandwidth. An a solo cello performance will have
			a smaller bandwidth.
			
			Returns:
				
				An Number which is the bandwidth (Hz) value for the current frame. Typical values 
				will be around several thousand hertz.

		*/	
		public function getBandwidth():Number{
			
			band = DSP.getBandwidth();
			return band;
		}
		
		/*
			Function: getRolloff
			
			This function calculates the frequency ceiling of the current frame. Rolloff is the frequency below which
			most of the instruments lie.
			
			Returns:
				
				A Number which is the rolloff value for the current frame. Typical values 
				will be around several thousand hertz.
				
		*/		
		public function getRolloff():Number{
			
			roll = DSP.getRolloff();
			return roll;
		}
		
		/*
			Function: getBeats
			
			This function performs a beat tracking analysis on the audio signal and returns the beat and tempo information.
			
			Returns:
				
				An array containing the beat notification and the tempo estimate. The beat notification frst element will be a zero '0'
				when there is no beat and one '1' on a frame where a beat is detected. 
				
		*/
		public function getBeats(w:Array, printFrame:Number):Array
		{
			var beat:Array = DSP.getBeats(w, printFrame);
			return beat;
		}		
		public function getAuto():Array
		{
			return DSP.getAuto();
		}		
		
		/*
			Function: getSpectrum
			
			This function calculates the magnitude of the frequency spectrum of the current frame.
			
			Parameters:
			
				fftSize - The number of DFT points used in performing the Fourier Transform. If you are
				unfamiliar with the Fourier Transform use default (0), this provides optimezed computation 
				and uses the next power of 2 greater than or equal to the frameSize.  

				useDB - A value of 1 will return the magnitude spectrum in decibels, 0 for unmodified magnitude.
			
			Returns:
				
				An Array of spectral amplitudes of length (fftSize/2 + 1). Only half of the spectrum is returned 
				since it is assumed that audio is the input signal and the magnitude spectrum is symmetric.
			
			Notes:
			
				This is the magnitude spectrum, only real values are returned.
		*/	
		public function getSpectrum(fftSize:Number, useDB:Number):Array{
						
			magArr = [];
			magArr = DSP.magSpectrum(fftSize, useDB);
			
			return magArr;
		}
		
		/*
			Function: getComplexSpectrum
			
			This function calculates the complex frequency spectrum of the current frame.
			
			Parameters:
			
				fftSize - The number of points used in calculating the Discrete Fourier Transform. If you are
				unfamiliar with the Fourier Transform use default (0), this is he quickest option and uses 
				the next power of 2 greater than or equal to the frameSize.  
			
			Returns:
				
				An Array containing the complex valued Discrete Fourier Transform of the current frame. The Array is of the form
				
				Re[0] Im[1] Re[2] Im[3] ... Re[N-2] Im[N - 1]
			
		*/	
		public function getComplexSpectrum(fftSize:Number):Array{
						
			fftArr = [];
			fftArr = DSP.FFT(fftSize);
			
			return fftArr;
		}		
		
		/*
			Function: getHarmonics
			
			This function computes the partials assoicated with the audio spectrum
			
			Returns:
				
				Nothing. getHarmFreqs and getHarmAmps return the partial frequencies and amplitudes.
				
			See Also:
				
				<getHarmonicFrequencies()>,
				<getHarmonicAmplitudes()>
		*/
		
		public function getHarmonics(numHarms:uint):void {
			DSP.getHarmonics(numHarms);
		}
		/*
			Function: getHarmonicFrequencies
			
			Returns the harmoinc Frequencies generated from the getHarmonics call. getHarmonics must be called before
			this.
			
			Returns:
				
				An Array of frequencies.
				
			See Also:
			
				<getHarmonicHarmonics()>,
				<getHarmonicAmplitudes()>
		*/		
		
		public function getHarmonicFrequencies():Array {		
			harmFreqs = DSP.getHarmonicFrequencies();
			return harmFreqs;
		}
		
		/*
			Function: getHarmonicAmplitudes
			
			Returns the harmonics amplitudes generated from the getHarmonics call. getHarmoincs must be called before
			this.
			
			Returns:
				
				An array of amplitudes.
				
			See Also:
			
				<getHarmonics()>,
				<getHarmonicFrequencies()>
		*/		
		public function getHarmonicAmplitudes():Array {

			harmAmps = DSP.getHarmonicAmplitudes();
			return harmAmps;
		}
		
		/*
			Function: getLPCoefficients
			
			Returns the coefficients from performing linear prediction (speech processing function) on the
			frame of audio.
			
			Parameters:
			
				order - The prediction order, usually in the range 8 - 14.
				
			Returns:
				
				An array containing the coefficients with the gain as the last number. The length of this
				array will be (order + 1).
				
			See Also:
			
				<DSPFunctions.c->LPC>
		*/
		public function getLPCoefficients(order:int):Array {	
			
			lpcArray = DSP.getLPC(order);
			
			return lpcArray;
		}		

		public function getFrequencyResponse(filterArray:Array, gain:Number):Array
		{
			freqResp = DSP.getFrequencyResponse(filterArray, gain);
			
			return freqResp;
		}

		/*
			Function: getPitch
			
			Returns the pitch of the frame
			
			Parameters:
				none
			Returns:
				pitch - The estimated pitch value

			See Also:
			
				<DATF.as->getPitch>			
		*/
		public function getPitch():Number {
			pitchVal = DSP.getPitch();
			return pitchVal;
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
			
			pitchVal = DSP.getPitchFromSpeech(pitchMin, pitchMax, intenThreshold);
			
			return pitchVal;
		}
		
	
		/*
			Function: filterAudioFIR
			
			Filters the audio with the given filter (array of coefficients).
			
			Parameters:
			
				filterCoefficients - The filter coefficients.						
		*/
		
		public function filterAudioFIR(filterCoefficients:Array):void{
			
			DSP.filterAudioFIR(filterCoefficients);
		}
		/*
			Function: filterAudioIIR
			
			Filters the audio with the given filter (array of coefficients).
			
			Parameters:
			
			numeratorCoefficients - The numerator coefficients.
			denominatorCoefficients - The denominator coefficients.			
		*/
		
		public function filterAudioIIR(numeratorCoefficients:Array, denominatorCoefficients:Array, gain:Number):void{
			
			DSP.filterAudioIIR(numeratorCoefficients, denominatorCoefficients, gain);
		}


		/*
			Group: Audio Processing Functions
		
			Function: reverb
			
			This function adds reverb to the output stream. The basis of the reverb algorithm applied is based on a well knowon
			"image" model to create a simulated room-impulse-response. By default, the reverb is applied to left and right 
			channels of your ALF object (if it is stereo).
			
			Parameters:
				
				* *activate* - A string value indicating whether reverb should be turned on or off.
							on - adds reverb to the processing chain. It will persist unless it is turned off with an explicit command
							off - removes reverb from the processing chain. It will remain off until it is turned on again.			
						
				* *level* - 	A value from 1-4 (1 is the lowest, 4 is the highest) specifying the level of reverb to be applied.
						-
				
				* *roomType* - 	A string specifying the type of room to simulate. The sound source and listener locations assume
								that the source is near the front of the room and the listener (mic) is at the center.					
								
						small - simulates a room of dimensions 10x10x8 in feet
						big - simulates a room of dimensions 20x20x8 in feet
						hall - simulates a 'hall' of dimensions 30x50x30 in feet
						
				Notes:
					Currently, reverb cannot be used simultaneously with Phase Vocoding.
			
		*/
		public function reverb(activate:String, level:uint, roomType:String):void {
			
			var roomX:Number, roomY:Number, roomZ:Number, srcX:Number, srcY:Number, srcZ:Number,
				micX:Number, micY:Number, micZ:Number;
			var echoStrength:Number;
			
			switch(level) {
				case 1:
					echoStrength = 0.25;
					break;
				case 2:
					echoStrength = 0.50;
					break;
				case 3:
					echoStrength = 0.75;
					break;
				case 4:
					echoStrength = 1.00;
					break;
				default:
					echoStrength = 0.0;
					break;
			}
			
			switch(roomType) {
				case "small":
						roomX = 3; roomY = 3; roomZ = 2.4; //makes the room 10x10x8 in feet
						srcX = 1.5, srcY = 1, srcZ = 1.5;
						micX = 1.5, micY = 2, micZ = 1.5;
					break;
				case "big":
						roomX = 6; roomY = 6; roomZ = 3; //makes the room 20x20x10 in feet
						srcX = 3, srcY = 1, srcZ = 1.5;
						micX = 3, micY = 4.5, micZ = 1.5;
					break;
				case "hall":
						roomX = 9; roomY = 15; roomZ = 9; //makes the hall 30x50x30 in feet
						srcX = 4.5, srcY = .5, srcZ = 1.5;
						micX = 4.5, micY = 7.5, micZ = 1.5;
					break;
				default:
						roomX = 3; roomY = 3; roomZ = 2.4; //makes the room 10x10x8 in feet
						srcX = 1.5, srcY = 1, srcZ = 1.5;
						micX = 1.5, micY = 2.8, micZ = 1.5;
					break;
			}
			
			DSP.addReverb(activate, level, roomX, roomY, roomZ,
							srcX, srcY, srcZ, micX, micY, micZ);
			
		}
		
		//reverbDemo is an un-documented function that allows you to specify the fulll room and
		//speaker/source locations through alf without being restricted to the default room sizes.
		public function reverbDemo(activate:String, level:Number,
							   roomX:Number, roomY:Number, roomZ:Number,
							   srcX:Number, srcY:Number, srcZ:Number,
							   micX:Number, micY:Number, micZ:Number):void{		
			
			DSP.addReverb(activate, level, roomX, roomY, roomZ,
						  srcX, srcY, srcZ, micX, micY, micZ);
		}
		
		/*
			Function: vocoder
			
			Transmits the vocoder parameters to the DATF. Note, vocoder cannot be used in combination
			with any reverb function since they share a common output chain. Using both simultaneously
			will likely produce undesirable effects.
			
			Parameters:
			
			active - a boolean value that indicates if the vocoder is on (1) or off(0). Note: after 
			turning the vocoder on, you must keep calling this function to make sure it stays on with the
			active parameter set to "on" (1) so it remains part of the audio processing chain. Likewise,
			when you wish to remove it, you must call the function with the "active" parameter set to off (0).
			newPitch - a number (0.5 - 2.0) indicating the factor by which to modify the tempo.
				0.5 correspoinds to an octave up and 2.0 is an octave below.
			newTempo = a number (0.5 - 2.0) indicating the factor by which to modify the the tempo.
				0.5 corresponds to twice the rate and 2.0 corresponds to half the rate.
				
			Notes:
				Currently, reverb cannot be used simultaneously with Reverb, or other processing functions.
		*/
		
		public function vocoder(active:Boolean, newPitch:Number, newTempo:Number): void {
			DSP.vocoder(active, newPitch, newTempo);
		}
		
		// An internal function to extract the information from the .wav file header and set
		// the sample rate and number of channels accordingly
		private function extractWaveHeader(waveData:URLLoader):void {
			var wfh_chunkID:String = waveData.data.readMultiByte(4,"utf");
			
			waveData.data.endian = Endian.LITTLE_ENDIAN;
			var wfh_chunkSize:uint = waveData.data.readUnsignedInt(); 

			waveData.data.endian = Endian.BIG_ENDIAN;
			var wfh_format:String = waveData.data.readMultiByte(4,"utf");
			var wfh_subChunk1D:String = waveData.data.readMultiByte(4,"iso-8859-1");

			waveData.data.endian = Endian.LITTLE_ENDIAN;	
			var wfh_subChunk1Size:int = waveData.data.readInt()
			var wfh_audioFormat:int = waveData.data.readShort();
			var wfh_channels:int = waveData.data.readShort();
			var wfh_fs:int = waveData.data.readUnsignedInt();
			var wfh_bytesPerSec:int = waveData.data.readUnsignedInt();
			var wfh_blockAlign:int = waveData.data.readShort()
			var wfh_bits:int = waveData.data.readUnsignedShort();

			waveData.data.endian = Endian.BIG_ENDIAN;		
			var wfh_dataChunkSignature:String = waveData.data.readMultiByte(4,'iso-8859-1')

			waveData.data.endian = Endian.LITTLE_ENDIAN;			
			var wfh_numBytes:int = waveData.data.readInt();
			var wfh_numSamples:int = wfh_numBytes/(wfh_bits/8);
			
			//set the number of samples per Channel
			var wfh_numSamplesPerChannel = wfh_numSamples/wfh_channels;

			/**************************** End Header Parsing **********************************/
			
			// Display information extracted from the header if specified
			if(verbose){
			
				trace('----------------------------------------------');
				trace('Wave File Information');
				trace('ChunkID: '+ wfh_chunkID);
				trace('ChunkSize: '+ wfh_chunkSize);
				trace('Format: '+ wfh_format);			
				trace('SubChunk1D: '+ wfh_subChunk1D);
				trace('SubChunk1Size: '+ wfh_subChunk1Size);			
				trace('Audio Format: '+ wfh_audioFormat);			
				trace('Channels: '+ wfh_channels);
				trace('SampleRate: '+ wfh_fs);
				trace('Bytes/Second: '+ wfh_bytesPerSec);			
				trace('BlockAlign: '+ wfh_blockAlign);
				trace('Bits/Sample: '+ wfh_bits);			
				trace('Data Chunk Signature: '+ wfh_dataChunkSignature);			
				trace('Data Chunk Length: ' + wfh_numBytes + " bytes     " + wfh_numSamples + " samples");
				trace('Byte position after reading header info: '+ waveData.data.position);
				trace('----------------------------------------------\n');
			
			}									
			
			// store the sampling rate and compute the duration of the audio track
			fs = wfh_fs;
			duration = wfh_numBytes/wfh_bytesPerSec;
			bytesPerSample = wfh_bytesPerSec/fs;
			
			// Set mono/stereo
			if(wfh_channels == 2){ 						
				numCh = 2;
				STEREO = true;
			}		
			else{
				 numCh = 1;
				 STEREO = false};
			if(!(fs == 22050 || fs == 44100)){trace('UNSUPPORTED SAMPLE RATE! ALF supports only 22kHz or 44.1kHz sample rates');}
			
		}
		
	}
	
	/*
		Group: Events
	
		Topic: ALF Events
		
		There are five events ALF dispatches that are essential to properly using the library.
						
			* *FILE_LOADED* - 	This event is dispatched when the audio file has finished loading. No other function calls should be made after
							the ALF object is created until *after* this event is received. For more information see 
							http://livedocs.adobe.com/flash/9.0/ActionScriptLangRefV3/flash/media/Sound.html#event:complete.
							Note that the load time will depend upon whether you are using Flash or AIR. AIR can access the local file system, 
							therefore load times will be short. If using Flash, the time it takes for this listener to dispatch after the ALF 
							constructor is called will vary significantly depending on filesize, filetype, and server/network speed. 
							
			* *NEW_FRAME*  	-This event is sychronized with the SampleDataEvent in the Actionscript Sound class. Currently, it is possible to
							use multiple ALF objects for playback and analysis of more than one track. However, appropriate handling of the 
							NEW_FRAME event is required to determine which ALF was responsible for dispatching the event. Processing should
							ONLY occur on the ALF responsible for the event. This can be determined by comparing evt.target.trackName to the
							trackName of the any one of your objects (i.e. if(evt.target.trackName == myALF.trackName). This structure may
							change in future versions of ALF.
							For more information see http://livedocs.adobe.com/flex/3/langref/flash/events/SampleDataEvent.html.
							
			* *FILE_COMPLETE* - This event is dispatched when the audio file has finished playing. When there is no more data for the Sound object
							to process (i.e. the last frame is reached) this event will be released.
			
			* *PROG_EVENT* -	This is event is dispatched in accordance with the ProgressEvent incurred from a new
							URLRequest for loading an audio file.
			* *URL_ERROR* - This event signals that there was a problem loading the audio file.

	*/
}