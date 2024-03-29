# Introduction

Thank you for trying the **Audio Processing Library for Flash** (ALF) developed by the **Music and Entertainment Technology Lab**
in the **Department of Electrical and Computer Engineering** at Drexel University. This library is intended to streamline audio
playback, modification, and feature extraction for Flash applications using Actionscript 3. Using ALF, it is simple to play
`.wav` and `.mp3` audio files while synchronizing visual events with the audio to create applications that are highly music
centric/reactive.

Developers who do not require significant control over the manner in which playback occurs are directed to use [ALF.as](src/ALF.as).
Those who want lower level control over the dynamic audio playback functionality of Actionscript3 should read the
documentation on [DATF.as](src/DATF.as).

To download the library as well as view a demo application please go to http://music.ece.drexel.edu/ALF.


# Release Notes

Here are known issues for each version as well as the changes for each software iteration.

### About: Version 1.0.4 (r19)
#### Updates
- *Added Algorithms*:
  -  Pitch tracking using autocorrelation method (getPitch). There is also a version that specifies a range of fundamental frequencies and a threshold for when there is an active audio signal present (getPitchFromSpeech).
  - Phase vocoding and beat tracking added to the functions available in ALF.


### About: Version 1.0.3
#### Updates
- *Added Algorithms*:
  - Phase vocoding and beat tracking added to the functions available in ALF.

### About: Version 1.0.3
#### Updates
- *Added Algorithms*:
  - Phase vocoding and beat tracking added to the functions available in ALF.

### About: Version 1.0.2
#### Updates
- *Feature Values*:
  - Fixed the issue of feature values returning incorrectly when reverb is in use.

### About: Version 1.0.1
#### Updates
- *LPC/getHarmonics*: The algorithm for LPC and getHarmonics has been updated and verified. 
- *Audio Framing*: The hann window of v1.0 was longer than the audio input, this has been fixed for this release.
- *reverb/filter*: The issue of the reverb not working properly for certain frame/sample rate combinations has been fixed.
#### Known Issues
- *Feature Values*: For a frame rate of 10fps *only* the feature values returned are not verified as correct. They follow the same contour as that in the Matlab verification program but are not the same. Percent error as high as 100% is present. All other frame rates work properly.
- *Feature Values*: When reverb is on, feature values will not have one-to-one correspondence for some (higher) frame rates.  This is a result of the buffering necessary for processing reverb. This will be fixed in the next version.

### About: Version 1.0
#### Known Issues
- *mp3 Playback*: There is an issue with .mp3 files not beginning playback for high frame rates, this is fixed in v1.0.1.
- *getHarmonics*: The function that extracts harmonics from the spectrum was not being calculated correctly, this stems from the linear prediction algorithm. This issue is fixed in 1.0.1. The array that contains the autocorrelation used in LPC also was not being cleared each frame. This is also fixed in v1.0.1.
- *reverb/filter*: There is an issue of certain frame rate/sample rate combinations causing choppy playback.

