﻿package {

	// Utilities:	
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


	public class DATFTest extends MovieClip{
		
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
		
		public function DATFTest(){
			
			// YOUR FILE GOES HERE
			var song:String = "TestSong.mp3";										
			
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