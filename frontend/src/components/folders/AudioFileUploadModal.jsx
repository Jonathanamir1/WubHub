// frontend/src/components/folders/AudioFileUploadModal.jsx
import React, { useState, useRef } from 'react';
import { FiX, FiUpload, FiFile, FiMusic } from 'react-icons/fi';
import api from '../../services/api';

const AudioFileUploadModal = ({
	projectId,
	folderId,
	folders,
	onClose,
	onFileUploaded,
}) => {
	const [files, setFiles] = useState([]);
	const [selectedFolderId, setSelectedFolderId] = useState(folderId);
	const [uploading, setUploading] = useState(false);
	const [uploadProgress, setUploadProgress] = useState({});
	const [error, setError] = useState('');
	const fileInputRef = useRef(null);

	// Flatten folder structure for select dropdown
	const flattenFolders = (foldersList, depth = 0, result = []) => {
		foldersList.forEach((folder) => {
			result.push({
				id: folder.id,
				name: folder.name,
				depth,
				path: folder.path,
			});

			if (folder.subfolders && folder.subfolders.length > 0) {
				flattenFolders(folder.subfolders, depth + 1, result);
			}
		});

		return result;
	};

	const flatFolders = flattenFolders(folders);

	const handleFileChange = (e) => {
		if (e.target.files) {
			// Convert FileList to array
			const fileArray = Array.from(e.target.files);
			// Filter for audio files
			const audioFiles = fileArray.filter(
				(file) =>
					file.type.startsWith('audio/') ||
					file.name.match(/\.(mp3|wav|aiff|flac|m4a|ogg|wma)$/i)
			);

			setFiles(audioFiles);
		}
	};

	const handleFolderChange = (e) => {
		setSelectedFolderId(e.target.value);
	};

	const handleSubmit = async (e) => {
		e.preventDefault();

		if (files.length === 0) {
			setError('Please select at least one audio file');
			return;
		}

		if (!selectedFolderId) {
			setError('Please select a folder');
			return;
		}

		setUploading(true);
		setError('');

		// Upload files sequentially
		for (let i = 0; i < files.length; i++) {
			const file = files[i];

			try {
				setUploadProgress((prev) => ({
					...prev,
					[file.name]: { progress: 0, status: 'uploading' },
				}));

				const formData = new FormData();
				formData.append('file', file);
				formData.append('filename', file.name);

				const response = await api.createAudioFile(
					projectId,
					selectedFolderId,
					formData,
					{
						onUploadProgress: (progressEvent) => {
							const percentCompleted = Math.round(
								(progressEvent.loaded * 100) / progressEvent.total
							);
							setUploadProgress((prev) => ({
								...prev,
								[file.name]: {
									progress: percentCompleted,
									status: 'uploading',
								},
							}));
						},
					}
				);

				setUploadProgress((prev) => ({
					...prev,
					[file.name]: { progress: 100, status: 'completed' },
				}));

				onFileUploaded(response.data);
			} catch (err) {
				console.error(`Error uploading file ${file.name}:`, err);

				setUploadProgress((prev) => ({
					...prev,
					[file.name]: { progress: 0, status: 'error' },
				}));
			}
		}

		setUploading(false);
	};

	return (
		<div className='fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50'>
			<div className='bg-ableton-dark-300 rounded-md shadow-xl w-full max-w-md'>
				<div className='flex justify-between items-center p-4 border-b border-ableton-dark-200'>
					<h2 className='text-xl font-medium flex items-center'>
						<FiMusic className='mr-2' /> Upload Audio Files
					</h2>

					<button
						onClick={onClose}
						className='text-gray-400 hover:text-white transition-colors'
					>
						<FiX className='w-5 h-5' />
					</button>
				</div>

				<form
					onSubmit={handleSubmit}
					className='p-4'
				>
					{error && (
						<div className='mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-md text-red-500 text-sm'>
							{error}
						</div>
					)}

					<div className='mb-4'>
						<label className='block text-sm text-gray-400 mb-1.5'>
							Select Folder <span className='text-red-500'>*</span>
						</label>
						<select
							value={selectedFolderId}
							onChange={handleFolderChange}
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 transition-all'
							required
						>
							{flatFolders.map((folder) => (
								<option
									key={folder.id}
									value={folder.id}
								>
									{folder.depth > 0 ? '─'.repeat(folder.depth) + ' ' : ''}
									{folder.name}
								</option>
							))}
						</select>
					</div>

					<div
						className='border-2 border-dashed rounded-md p-6 flex flex-col items-center justify-center mb-4 transition-colors border-ableton-dark-100 hover:border-ableton-dark-50 cursor-pointer'
						onClick={() => fileInputRef.current?.click()}
					>
						// frontend/src/components/folders/AudioFileUploadModal.jsx
						(continued)
						<input
							ref={fileInputRef}
							type='file'
							multiple
							accept='audio/*,.mp3,.wav,.aiff,.flac,.m4a,.ogg,.wma'
							onChange={handleFileChange}
							className='hidden'
						/>
						{files.length === 0 ? (
							<>
								<FiUpload className='w-10 h-10 text-gray-400 mb-2' />
								<p className='font-medium text-center'>
									Click to browse or drag & drop audio files
								</p>
								<p className='text-sm text-gray-400 mt-1'>
									Supported formats: MP3, WAV, AIFF, FLAC, M4A, OGG, WMA
								</p>
							</>
						) : (
							<>
								<FiMusic className='w-10 h-10 text-ableton-blue-400 mb-2' />
								<p className='font-medium text-center'>
									{files.length} audio file{files.length !== 1 ? 's' : ''}{' '}
									selected
								</p>
								<button
									type='button'
									className='mt-2 text-sm text-ableton-blue-400 hover:text-ableton-blue-300'
									onClick={(e) => {
										e.stopPropagation();
										setFiles([]);
									}}
								>
									Clear selection
								</button>
							</>
						)}
					</div>

					{/* File list with upload progress */}
					{files.length > 0 && (
						<div className='mb-4 max-h-40 overflow-y-auto'>
							{files.map((file) => (
								<div
									key={file.name}
									className='py-2 border-b border-ableton-dark-200 last:border-0'
								>
									<div className='flex justify-between items-center mb-1'>
										<div className='flex items-center'>
											<FiFile className='mr-2 text-gray-400' />
											<span className='text-sm truncate max-w-xs'>
												{file.name}
											</span>
										</div>
										<span className='text-xs text-gray-400'>
											{(file.size / 1024 / 1024).toFixed(2)} MB
										</span>
									</div>

									{uploadProgress[file.name] && (
										<div className='w-full h-1.5 bg-ableton-dark-200 rounded-full overflow-hidden'>
											<div
												className={`h-full rounded-full ${
													uploadProgress[file.name].status === 'error'
														? 'bg-red-500'
														: 'bg-ableton-blue-500'
												}`}
												style={{
													width: `${uploadProgress[file.name].progress}%`,
												}}
											></div>
										</div>
									)}
								</div>
							))}
						</div>
					)}

					<div className='flex space-x-3'>
						<button
							type='button'
							onClick={onClose}
							className='flex-1 py-3 bg-ableton-dark-200 hover:bg-ableton-dark-100 text-white rounded-md transition-colors'
							disabled={uploading}
						>
							Cancel
						</button>

						<button
							type='submit'
							disabled={uploading || files.length === 0}
							className={`flex-1 py-3 rounded-md transition-colors ${
								uploading || files.length === 0
									? 'bg-ableton-dark-200 text-gray-500 cursor-not-allowed'
									: 'bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white'
							}`}
						>
							{uploading ? 'Uploading...' : 'Upload Files'}
						</button>
					</div>
				</form>
			</div>
		</div>
	);
};

export default AudioFileUploadModal;
