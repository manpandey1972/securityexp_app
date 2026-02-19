# Ringtone Assets

This directory contains audio files for the app:
- `ringtone.mp3`: Call ringtone sound (primary file used in the app)
- `ringtone.wav`: Original WAV source file

## Format

The ringtone is stored as MP3 (4.9KB) for optimal cross-platform compatibility:
- Works on iOS, Android, and Web platforms
- MP3 format has better browser support than WAV
- File is small and suitable for looping

## Looping Behavior

The ringtone plays on loop when:
- An **incoming call** is received (receiver hears the ring)
- A **call is being initiated** (caller hears dialing tone)

The ringtone stops when:
- User accepts the call
- User declines the call  
- Call connection is established
- Call times out

## Customization

To use a different ringtone:
1. Replace `ringtone.mp3` with your own MP3 file
2. Ensure it loops cleanly (starts and ends without silence)
3. Keep file size under 10KB for optimal app size
4. Ensure it's in MP3 format for cross-platform compatibility
