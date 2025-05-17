// frontend/src/components/audio/AudioPlayer.jsx
import React, { useState, useEffect, useRef } from 'react';
import { FiPlay, FiPause, FiVolume2, FiVolumeX } from 'react-icons/fi';

const AudioPlayer = ({ audioFile }) => {
	const [isPlaying, setIsPlaying] = useState(false);
	const [duration, setDuration] = useState(0);
	const [currentTime, setCurrentTime] = useState(0);
	const [volume, setVolume] = useState(0.75);
	const [isMuted, setIsMuted] = useState(false);

	const audioRef = useRef(new Audio());
	const animationRef = useRef(null);

	useEffect(() => {
		const audio = audioRef.current;

		// Set up audio source
		if (audioFile?.file_url) {
			audio.src = audioFile.file_url;
			audio.load();
		}

		// Event listeners
		const setAudioData = () => {
			setDuration(audio.duration);
			setCurrentTime(0);
		};

		const setAudioTime = () => setCurrentTime(audio.currentTime);

		const handleEnded = () => {
			setIsPlaying(false);
			cancelAnimationFrame(animationRef.current);
		};

		audio.addEventListener('loadeddata', setAudioData);
		audio.addEventListener('timeupdate', setAudioTime);
		audio.addEventListener('ended', handleEnded);

		// Set volume
		audio.volume = volume;
		audio.muted = isMuted;

		// Clean up
		return () => {
			cancelAnimationFrame(animationRef.current);
			audio.pause();

			audio.removeEventListener('loadeddata', setAudioData);
			audio.removeEventListener('timeupdate', setAudioTime);
			audio.removeEventListener('ended', handleEnded);
		};
	}, [audioFile]);

	// Handle play state changes
	useEffect(() => {
		const audio = audioRef.current;

		if (isPlaying) {
			audio.play().catch((error) => {
				console.error('Error playing audio:', error);
				setIsPlaying(false);
			});

			animationRef.current = requestAnimationFrame(whilePlaying);
		} else {
			audio.pause();
			cancelAnimationFrame(animationRef.current);
		}
	}, [isPlaying]);

	// Handle volume changes
	useEffect(() => {
		const audio = audioRef.current;
		audio.volume = volume;
		audio.muted = isMuted;
	}, [volume, isMuted]);

	const whilePlaying = () => {
		setCurrentTime(audioRef.current.currentTime);
		animationRef.current = requestAnimationFrame(whilePlaying);
	};

	const togglePlayPause = () => {
		setIsPlaying(!isPlaying);
	};

	const handleProgressChange = (e) => {
		const newTime = e.target.value;
		setCurrentTime(newTime);
		audioRef.current.currentTime = newTime;
	};

	const handleVolumeChange = (e) => {
		const newVolume = e.target.value;
		setVolume(newVolume);
		if (newVolume === 0) {
			setIsMuted(true);
		} else if (isMuted) {
			setIsMuted(false);
		}
	};

	const toggleMute = () => {
		setIsMuted(!isMuted);
	};

	const formatTime = (seconds) => {
		if (isNaN(seconds)) return '0:00';

		const mins = Math.floor(seconds / 60);
		const secs = Math.floor(seconds % 60)
			.toString()
			.padStart(2, '0');
		return `${mins}:${secs}`;
	};

	return (
		<div className='bg-ableton-dark-300 rounded-lg border border-ableton-dark-200 p-4'>
			<div className='mb-3 flex items-center'>
				<div className='mr-4'>
					<button
						onClick={togglePlayPause}
						className='w-10 h-10 rounded-full bg-ableton-blue-500 hover:bg-ableton-blue-600 flex items-center justify-center transition-colors'
					>
						{isPlaying ? <FiPause size={18} /> : <FiPlay size={18} />}
					</button>
				</div>

				<div className='flex-grow'>
					<div className='font-medium'>
						{audioFile?.filename || 'No file selected'}
					</div>
					<div className='text-xs text-gray-400'>
						{formatTime(currentTime)} / {formatTime(duration)}
					</div>
				</div>

				<div className='flex items-center ml-2'>
					<button
						onClick={toggleMute}
						className='text-gray-400 hover:text-white p-1'
					>
						{isMuted ? <FiVolumeX size={18} /> : <FiVolume2 size={18} />}
					</button>

					<input
						type='range'
						min='0'
						max='1'
						step='0.01'
						value={volume}
						onChange={handleVolumeChange}
						className='w-16 h-1 ml-2 accent-ableton-blue-500'
					/>
				</div>
			</div>

			<div className='relative flex items-center'>
				<input
					type='range'
					min='0'
					max={duration || 100}
					value={currentTime}
					onChange={handleProgressChange}
					className='w-full h-1.5 accent-ableton-blue-500 bg-ableton-dark-200 rounded-full appearance-none'
					disabled={!audioFile}
				/>
			</div>
		</div>
	);
};

export default AudioPlayer;
