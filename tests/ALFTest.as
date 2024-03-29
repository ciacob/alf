﻿/*
   Copyright 2009 Music and Entertainment Technology Laboratory
   - Drexel University
   
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

package {
			
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.net.*;
	import flash.geom.ColorTransform;	
	import flash.geom.Rectangle;
	import flash.net.FileReference;
	import flash.events.*;
	import flash.utils.*;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import fl.events.ListEvent;
	import fl.controls.Slider;
	import fl.controls.Label;
	import fl.events.SliderEvent;
	import flash.filters.BevelFilter;
	import flash.geom.ColorTransform;
	import flash.system.System;
	import flash.text.*;
	import ALF;
	
	public class ALFTest extends MovieClip{
		
		//ALF-objected related variables
		private var str:String;					//String for audio filename
		private var alfArray:Array;				//an array that holds ALF objects initialized here
		private var maxAlfs:int = 3;			//maximum allowable number of ALFs (arbitrary)
		private var INITIALIZED:Boolean = false;
		
		//Benchmarking
		var frameNum:uint = 0;
		public var time1:Number;
		public var time2:Number;
		public var total:Number;
		public var sysMemory:Number;
		public var sysMemoryTimer:Timer;
		
		//Features
		public var inten:Number, cent:Number, band:Number, roll:Number, flux:Number;
		var centArr:Array, bandArr:Array, intenArr:Array, rollArr:Array, fluxArr:Array, spectrum:Array, fft:Array;
		var beatCount:Number = 1;
		
		//For Harmonics
		public var freqs:Array, mags:Array;
		public var pitchEstimate:Number;
		public var numHarmonics:int = 1;
		
		//Buttons
		public var reverbStatus:Boolean = false;
		public var reverbActive:String = "off";
		public var harmonicsActive:Boolean = false;
		public var audioPlaying:Boolean = false;
		
		//Display
		var roomRect:Rectangle = new Rectangle(0, 0, 200, 200);
		
		//Room Stuff
		private const roomXwidth:Number = 8; //8 meters wide
		private const roomYwidth:Number = 8;
		private const roomZheight:Number = 3;
		private var srcX:Number = 0;
		private var srcY:Number = 0;
		private const srcZ:Number = 2;		//make the src height always 2 meters high
		private var micX:Number = 0;
		private var micY:Number = 0;
		private const micZ:Number = 2;		//mic height should be approximately 2 meters, ~6feet
		private var echoStrength:Number = 0.5;
		
		//vocoder stuff
		private var vocodePitch:Number = 1;
		private var vocodeTempo:Number = 1;
		
		//list look and feel stuff
		public var trackArray:Array;
		var listTextFormat:TextFormat;
		
		//button look and feel
		private var upBevel:BevelFilter = new BevelFilter(1, 45, 0xFFFFFF, 1, 0x000000, 1, 2, 2, 1, 1);
		private var overBevel:BevelFilter = new BevelFilter(5, 45, 0xFFFFFF, 1, 0x000000, 1, 20, 20, 1, 3, 'inner', false);
		private var downBevel:BevelFilter = new BevelFilter(-1, 45, 0xFFFFFF, 1, 0x000000, 1, 2, 2, 1, 1);
		
		public function ALFTest(){
			
			alfArray = new Array();			//an array that holds ALF objects
			
			trackList.alpha = .5;
			
			vocoderCB.label = ""; 			//checkBox text label
			trackList.addEventListener(ListEvent.ITEM_CLICK, trackSelected);
			
			//formatting stuff for the componenet appearances
			listTextFormat = new TextFormat();
			listTextFormat.color = 0xFFFFFF;
			listTextFormat.size = 12;
			songComboBox.textField.setStyle("textFormat", listTextFormat);
			
			trackArray = new Array();
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/SA1_44kHz_stereo.wav');	
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/IronAndWine.wav');
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/DMajScale.wav');
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/Opeth.mp3');
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/samp1.wav');
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/samp2.wav');
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/samp3.wav');
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/samp4.wav');
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/samp5.wav');
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/samp6.wav');
			trackArray.push('http://music.ece.drexel.edu/ALFaudio/speech_dft.mp3');


			//init the combo box
			songComboBox.addItem({label:"--make a selection below--"});
			songComboBox.addItem({label:"speech"});
			songComboBox.addItem({label:"acoustic"});
			songComboBox.addItem({label:"Piano Major Scale"});	
			songComboBox.addItem({label:"Acoustic-Vocal"});		
			songComboBox.addItem({label:"warshwater"});
			songComboBox.addItem({label:"efficiency"});
			songComboBox.addItem({label:"husky"});
			songComboBox.addItem({label:"divorcee"});
			songComboBox.addItem({label:"dishes"});
			songComboBox.addItem({label:"pewter"});			
			songComboBox.addItem({label:"dftSpeech"});
			songComboBox.addEventListener(Event.CHANGE, songChangedHandler);
			
			
			//labeling
			brightnessBtn.label = "";
			fluxBtn.label = "";
			bandwidthBtn.label = "";
			intensityBtn.label = "";
			rolloffBtn.label = "";
			complexSpectrumBtn.label = '';
			magnitudeSpectrumBtn.label = '';
			
			brightnessBtn.selected = false;
			fluxBtn.selected = false;
			bandwidthBtn.selected = false;
			intensityBtn.selected = false;
			rolloffBtn.selected = false;
			complexSpectrumBtn.selected = false;
			magnitudeSpectrumBtn.selected = false;
			
			// Storage Arrays//
			centArr = new Array();
			bandArr = new Array();
			intenArr = new Array();
			rollArr = new Array();
			fluxArr = new Array();
			spectrum = new Array();		
			fft = new Array();
			
			sysMemoryTimer = new Timer(500, 0);
			sysMemoryTimer.addEventListener(TimerEvent.TIMER, memTimerHandler);
			sysMemoryTimer.start();
		}

		// ALF Frame event:
		/* since this callback is shared by potentially multiple ALF objects,
			we have to specify which ALF we want to process on for each callback.
			The ALF is identified by the event.target.trackName attribute for matching
		*/
		
		public function onFrame(event:Event):void{
			
			if(event.target.trackName == alfArray[0].trackName) {
							//----------- Check for selected features ----------
				if(brightnessBtn.selected) {				
					cent = alfArray[0].getBrightness();
					centArr.push(cent);
					brightnessVal.text = (cent.toFixed(2)).toString() + ' Hz';
				}
				if(intensityBtn.selected) {
					inten = alfArray[0].getIntensity();
					intenArr.push(inten);
					intensityVal.text = (inten.toFixed(2)).toString();
				}
				if(rolloffBtn.selected) {
					roll = alfArray[0].getRolloff();
					rollArr.push(roll);
					rolloffVal.text = (roll.toFixed(2)).toString() + ' Hz';
				}
				if(fluxBtn.selected) {
					flux = alfArray[0].getFlux();
					fluxArr.push(flux);
					fluxVal.text = (flux.toFixed(2)).toString();
				}
				if(bandwidthBtn.selected) {
					band = alfArray[0].getBandwidth();
					bandArr.push(band);
					bandwidthVal.text = (band.toFixed(2)).toString() + ' Hz';
				}
				
				pitchWheelOff();									//turn off any lit pitch buttons
				if(harmonicsActive) { 								//harmonics handling code
					pitchEstimate = alfArray[0].getPitch();
					findPitch(pitchEstimate);								//code to light up the pitches
				}
				alfArray[0].getHarmonics(1);

				if(reverbActive == "on") {
					//if reverb is on, get the src and mic positions
					micX = (theMic.x/theRoom.x * roomXwidth);
					micY = (theMic.y/theRoom.y * roomYwidth);
					srcX = (theSpeaker.x/theRoom.x * roomXwidth);
					srcY = (theSpeaker.y/theRoom.y * roomYwidth);
				}
	
				//reverbDemo is an undocumented function, but allows full access to the DATF parameters
				//you cannot run reverb and vocoder simultaneously
				if(!vocoderCB.selected) {
					alfArray[0].reverbDemo(reverbActive, echoStrength,
					roomXwidth, roomYwidth, roomZheight,
					srcX, srcY, srcZ,
					micX, micY, micZ);
				}
				
				//vocoder takes a boolean value to turn it on (1) or off(0)...
				//the desired pitch change and tempo change, and the overlap factor
				if(reverbActive == "off") {
					alfArray[0].vocoder(vocoderCB.selected, vocodePitch, vocodeTempo);
				}
			}
			
			//if using multiple ALFs...do something like this
/*			if(alfArray.length > 1) {
				if(event.target.trackName == alfArray[1].trackName) {
					alfArray[1].vocoder(vocoderCB.selected, 0.84, 1);
				}
			}
*/

			frameNum++;
		}
		
		private function trackSelected(evt:ListEvent):void {
			//trace('an item was clicked' + evt.rowIndex);
		}
		
		private function memTimerHandler(evt:TimerEvent):void {
			// For bench-marking purposes, we get a read out on the system memory usage here
			sysMemory = System.totalMemory;
			statusText.text = 'Active Memory Use: ' + ((sysMemory/1000000).toFixed(3)).toString() 
				+ ' MB';
		}
				
		public function initButtons():void{				
			playButton.buttonMode = true;
			stopButton.buttonMode = true;
			pauseButton.buttonMode = true;
			
			//room reverb handling below...
			reverbButton.addEventListener(MouseEvent.CLICK, reverbHandler);
			theRoom.addChild(theSpeaker); 			//make the icons children of the room
			theRoom.addChild(theMic);
			
			//add click handling
			theSpeaker.addEventListener(MouseEvent.MOUSE_DOWN, iconSelected);
			theMic.addEventListener(MouseEvent.MOUSE_DOWN, iconSelected);
			theSlider.addEventListener(SliderEvent.CHANGE, sliderValueChanged);
			
			//initial positioins
			theSpeaker.x = 50; theSpeaker.y = 50;
			theMic.x = 80; theMic.y = 80;
			
			//slider info
			theSlider.maximum = 100;
			theSlider.snapInterval = 10;
			theSlider.tickInterval = 10;
			
			//vocoder sliders
			pitchSlider.minimum = -12;
			pitchSlider.maximum = 12;
			pitchSlider.snapInterval = 1;
			pitchSlider.tickInterval = 1;
			pitchSlider.liveDragging = true;
			pitchSlider.value = 0;
			pitchSlider.addEventListener(SliderEvent.CHANGE, pitchChange);
			
			tempoSlider.minimum = -1;
			tempoSlider.maximum = 1;
			tempoSlider.snapInterval = 0.05;
			tempoSlider.tickInterval = 0.1;
			tempoSlider.value = 0;
			tempoSlider.liveDragging = true;
			tempoSlider.addEventListener(SliderEvent.CHANGE, tempoChange);
			
			//audio control appearance
			playButton.alpha = .33;
			stopButton.alpha = .33;
			pauseButton.alpha = .33;
			
			//for harmoincs
			noteButton.addEventListener(MouseEvent.MOUSE_DOWN, harmonicsToggled);
			pitchWheelOff();
			
			//printing stuff, will be removed soon...
			printFeaturesButton.alpha = .3;
		}
		
		// ------------ Audio Playback --------------
		public function songChangedHandler(evt:Event):void {
			var comboIndex:int = evt.target.selectedIndex;
			trace('You have selected: ' + trackArray[comboIndex-1]);
			
			centArr = [];
			bandArr = []; 
			intenArr = []; 
			rollArr = []; 
			fluxArr = []; 
			spectrum = []; 
			fft = [];			
					
			// Initialize the ALF
			if(comboIndex > 0){
				playButton.removeEventListener(MouseEvent.CLICK, playHandler);
				stopButton.removeEventListener(MouseEvent.CLICK	, stopHandler);
				pauseButton.removeEventListener(MouseEvent.CLICK, pauseHandler);
				playButton.alpha = .3; stopButton.alpha = .3; pauseButton.alpha = .3;
				str = trackArray[comboIndex - 1];
				
				//parse off the track name from the file path
				var res:Array = trackArray[comboIndex-1].split('/');
				
				if(alfArray.length < maxAlfs){ //we impose a 3 track limit on alf right now
					
					//add the track name to the track list
					trackList.addItem({label:res[res.length - 1]});
					
					// added a '2' to the arguments to reflect starting position
					var newALF:ALF = new ALF(str, 0, 30, false, 0);
					newALF.addEventListener(newALF.FILE_LOADED, audioLoaded);	
					newALF.addEventListener(newALF.PROG_EVENT, loadProgress);
					newALF.addEventListener(newALF.NEW_FRAME, onFrame);
					newALF.addEventListener(newALF.FILE_COMPLETE, audioFinished);
					newALF.addEventListener(newALF.URL_ERROR, loadError);
					alfArray.push(newALF);
					
				}else{
					var newTrackInd:int = trackList.selectedIndex;
					trackList.addItemAt({label:res[res.length - 1]}, newTrackInd);
					trackList.removeItemAt(newTrackInd + 1);
					//reinitialize the ALF
					alfArray[newTrackInd].loadNewSong(str, 0);
				}
			}
		}
		
		public function audioLoaded(event:Event):void{
			loadText.text = 'Finished loading... ' + event.target.trackName;
			statusText.text = loadText.text;
			initButtons();
			playButton.addEventListener(MouseEvent.CLICK, playHandler);
			playButton.alpha = 1;
		}		
		
		public function playHandler(event:Event):void{
			if(!audioPlaying) {
				audioPlaying = true;
				//audio control handling below...
				playButton.removeEventListener(MouseEvent.CLICK, playHandler);
				stopButton.addEventListener(MouseEvent.CLICK, stopHandler);
				pauseButton.addEventListener(MouseEvent.CLICK, pauseHandler);
				songComboBox.enabled = false;
				printFeaturesButton.removeEventListener(MouseEvent.CLICK, printFeaturesHandler);
				printFeaturesButton.alpha = .3;
				playButton.alpha = .30;
				pauseButton.alpha = 1;
				stopButton.alpha = 1;
				//start all the ALFs
				for(var i:int = 0; i < alfArray.length; i++){
					alfArray[i].startAudio();
				}
			}
		}
		
		public function stopHandler(event:Event):void{
			if(audioPlaying) {
				playButton.addEventListener(MouseEvent.CLICK, playHandler);
				playButton.alpha = 1;
				stopButton.alpha = .3;
				pauseButton.alpha = .3;
				songComboBox.enabled = true;
				audioPlaying = false;
				//stop all the ALFS
				for(var i:int = 0; i < alfArray.length; i++){
					alfArray[i].stopAudio();
				}
			}
		}
		
		public function pauseHandler(event:Event):void{
			if(audioPlaying) {
				playButton.addEventListener(MouseEvent.CLICK, playHandler);
				playButton.alpha = 1;
				pauseButton.alpha = .3;
				stopButton.alpha =  .3;
				audioPlaying = false;
				//pause all the ALFS
				for(var i:int = 0; i < alfArray.length; i++){
					alfArray[i].pauseAudio();
				}
			}
		}
		
		public function audioFinished(event:Event):void{
			trace('audioFinished target: ' + event.target.trackName);
			var alfsDone:Boolean = true;
			
			for(var i:int = 0; i < alfArray.length; i++){
					alfsDone = alfsDone && alfArray[i].STOP;
			}
			
			if(alfsDone){
				audioPlaying = false;
				playButton.addEventListener(MouseEvent.CLICK, playHandler);
				printFeaturesButton.addEventListener(MouseEvent.CLICK, printFeaturesHandler);
				printFeaturesButton.alpha = 1;
				songComboBox.enabled = true;
				playButton.alpha = 1;
				stopButton.alpha = .3;
				pauseButton.alpha = .3;
				trace('all ALFS are finished playing.....'); 
				trace('---------------------------------------');
				frameNum = 0;
			}
		}
		
		// --------------- Vocoder ------------------
		public function sliderValueChanged(evt:SliderEvent):void { echoStrength = evt.value/100; }
		
		public function pitchChange(evt:SliderEvent):void { vocodePitch = Math.pow(2, evt.value/12);}
		
		public function tempoChange(evt:SliderEvent):void { vocodeTempo = Math.pow(2, evt.value); }
		
		
		// ------------- Harmonics ------------------
		public function harmonicsToggled(evt:Event):void {
			if(harmonicsActive) {
				harmonicsActive = false;
				noteButton.filters = [overBevel, upBevel];
			}
			else {
				harmonicsActive = true;
				noteButton.filters = [overBevel, downBevel];
			}
		}
		
		// Handle setting the nuber of harmonics extracted
		public function buttonDown(evt:MouseEvent):void {
			evt.target.alpha = .33;
		}
		public function buttonUp(evt:MouseEvent):void {
			evt.target.alpha = 1;
		}
		
		
		// Find the pitch of the associated harmonics and light the corresponding wedge
		private function findPitch(pitch:Number):void {

			var numOctaves:Number = 7;
			var numSemitones:Number = 12;				
			var currentNote:Number, noteUp:Number, noteDown:Number;
			var midiNote:Number;

			// Find the midi note associated with the pitch
			for(var step:Number = 0; step < numSemitones*numOctaves; step++) {				
				currentNote = 27.5*Math.pow(2,step/12);
				noteUp = 27.5*Math.pow(2,(step+1)/12);
				noteDown = 27.5*Math.pow(2,(step-1)/12);
				if(pitch > (currentNote - (currentNote - noteDown)/2) && pitch <= (currentNote + (noteUp-currentNote)/2))
				{
					midiNote = Math.round(12*Math.log(currentNote/27.5)*Math.LOG2E);
					break;
				}
			}

			// Find pitch class
			var baseNote:Number = midiNote;
			while(baseNote > 12){
				baseNote = baseNote - 12;
			}			
				
			//now turn on the appropriate button
			switch(baseNote){
				case 1:		aSharpButton.alpha = 1;
							break;
				case 2:		bButton.alpha = 1;
							break;
				case 3:		cButton.alpha = 1;
							break;
				case 4:		cSharpButton.alpha = 1;
							break;
				case 5:		dButton.alpha = 1;
							break;
				case 6:		dSharpButton.alpha = 1;
							break;
				case 7: 	eButton.alpha = 1;
							break;
				case 8:		fButton.alpha = 1;
							break;
				case 9:		fSharpButton.alpha = 1;
							break;
				case 10:	gButton.alpha = 1;
							break;
				case 11:	gSharpButton.alpha = 1;
							break;
				case 12:	aButton.alpha = 1;
							break;			
				default: 	 pitchWheelOff();
			}

		}
		
		// Turn all lit pitch wheel harmonics off
		private function pitchWheelOff():void {
			aButton.alpha = .30;
			aSharpButton.alpha = .30;
			bButton.alpha = .30;
			cButton.alpha = .30;
			cSharpButton.alpha = .30;
			dButton.alpha = .30;
			dSharpButton.alpha = .30;
			eButton.alpha = .30;
			fButton.alpha = .30;
			fSharpButton.alpha = .30;
			gButton.alpha = .30;
			gSharpButton.alpha = .30;
		}			

		// -------------- Reverb ---------------------
		public function reverbHandler(evt:Event):void {
			if(reverbStatus) {
				//if its on, turn it off
				reverbStatus = false;
				reverbActive = "off";
				reverbButton.filters = [overBevel, upBevel];
			} else {
				//of its off, turn it on
				reverbStatus = true;
				reverbActive = "on";
				reverbButton.filters = [overBevel, downBevel];
			}
		}
		
		public function loadProgress(evt:Event):void {
			var orgWidth:Number = 264.75;
			loadText.text = 'Loading Audio.... ' + ((evt.target.loadProgress*100).toFixed(2)).toString() + '%';
			loaderBar.width = orgWidth * evt.target.loadProgress;
		}
		
		public function loadError(evt:Event):void {
			statusText.text = "Error loading specified URL. Check network connection. ";
		}
		
		//speaker/mic-icon handling functions
		public function iconSelected(evt:Event):void {
			evt.target.addEventListener(MouseEvent.MOUSE_UP, iconReleased);
			evt.target.startDrag(false, roomRect);
		}
		
		public function iconReleased(evt:Event):void { evt.target.stopDrag(); }
				
		// Prints spectral feature values to a .txt file
		public function printFeaturesHandler(evt:Event):void {
			var file:FileReference = new FileReference();
			var featureArray:Array = new Array();			
			
			if(complexSpectrumBtn.selected) {
				featureArray.push('*Complex* ' + arr2str(fft) + '\n');
			}
			if(magnitudeSpectrumBtn.selected) {
				featureArray.push('*Magnitude* ' + arr2str(spectrum) + '\n');
			}
			if(brightnessBtn.selected) {			
				featureArray.push('*Centroid* ' + arr2str(centArr) + '\n');
			}
			if(fluxBtn.selected) {
				featureArray.push('*Flux* ' + arr2str(fluxArr) + '\n');
			}
			if(bandwidthBtn.selected) {
				featureArray.push('*Bandwidth* ' + arr2str(bandArr) + '\n');
			}
			if(intensityBtn.selected) {
				featureArray.push('*Intensity* ' + arr2str(intenArr) + '\n');
			}
			if(rolloffBtn.selected) {
				featureArray.push('*Rolloff* ' + arr2str(rollArr) + '\n');
			}
			
			file.save(featureArray, "features.txt");
			
			fft.splice(0); spectrum.splice(0); centArr.splice(0); fluxArr.splice(0);
			bandArr.splice(0); intenArr.splice(0); rollArr.splice(0); featureArray.splice(0);
		}
		
		// Convert an array to a string
		public function arr2str(myArray:Array):String{
			var i:uint;
			var output:String = "";
			for(i = 0; i < myArray.length; i++){ output = output+ " " + myArray[i].toString();}
			return output;
		}
	}
}
