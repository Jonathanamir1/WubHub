// frontend/src/components/folders/BatchUploadModal.jsx
import React, { useState, useRef, useCallback } from 'react';
import { FiX, FiUpload, FiFolder, FiFile, FiCheck } from 'react-icons/fi';
import api from '../../services/api';

const BatchUploadModal = ({ projectId, onClose, onUploadComplete }) => {
	const [files, setFiles] = useState([]);
	const [folderStructure, setFolderStructure] = useState({});
	const [uploading, setUploading] = useState(false);
	const [progress, setProgress] = useState(0);
	const [error, setError] = useState('');
	const [uploadedCount, setUploadedCount] = useState(0);
	const [createdFolders, setCreatedFolders] = useState({});

	const dragCounter = useRef(0);
	const dropAreaRef = useRef(null);

	// Process directory structure from FileSystemEntry objects
	const processEntry = useCallback(async (entry, path = '') => {
		if (entry.isFile) {
			return new Promise((resolve) => {
				entry.file((file) => {
					// Only process audio files
					if (
						file.type.startsWith('audio/') ||
						file.name.match(/\.(mp3|wav|aiff|flac|m4a|ogg|wma)$/i)
					) {
						// Add path data to the file object
						const fileWithPath = Object.assign(file, {
							relativePath: path ? `${path}/${file.name}` : file.name,
							webkitRelativePath: path,
						});
						resolve({ file: fileWithPath, type: 'file' });
					} else {
						resolve(null);
					}
				});
			});
		} else if (entry.isDirectory) {
			const dirReader = entry.createReader();

			return new Promise((resolve) => {
				const readEntries = () => {
					dirReader.readEntries(async (entries) => {
						if (entries.length === 0) {
							resolve({
								name: entry.name,
								path: path ? `${path}/${entry.name}` : entry.name,
								type: 'directory',
								children: [],
							});
						} else {
							const folderPath = path ? `${path}/${entry.name}` : entry.name;
							const childPromises = entries.map((childEntry) =>
								processEntry(childEntry, folderPath)
							);
							const children = await Promise.all(childPromises);

							const filteredChildren = children.filter(Boolean);

							resolve({
								name: entry.name,
								path: folderPath,
								type: 'directory',
								children: filteredChildren,
							});
						}
					});
				};

				readEntries();
			});
		}
	}, []);

	// Handle file drop event
	const handleDrop = useCallback(
		async (e) => {
			e.preventDefault();
			e.stopPropagation();

			dragCounter.current = 0;
			dropAreaRef.current.classList.remove(
				'border-ableton-blue-500',
				'bg-ableton-blue-500/10'
			);

			// Get items from the drop event
			const items = e.dataTransfer.items;

			if (items) {
				setError('');

				// Process all entries
				const entries = [];
				for (let i = 0; i < items.length; i++) {
					const item = items[i];
					let entry;

					// Get as FileSystemEntry (directory or file)
					if (item.webkitGetAsEntry) {
						entry = item.webkitGetAsEntry();
					} else if (item.getAsEntry) {
						entry = item.getAsEntry();
					}

					if (entry) {
						const processedEntry = await processEntry(entry);
						if (processedEntry) {
							entries.push(processedEntry);
						}
					}
				}

				// Organize entries and extract files
				const newFiles = [];
				const newFolderStructure = {};

				const processEntries = (entryList, parentPath = '') => {
					entryList.forEach((entry) => {
						if (entry.type === 'file') {
							newFiles.push(entry.file);
						} else if (entry.type === 'directory') {
							const folderPath = entry.path;
							newFolderStructure[folderPath] = {
								name: entry.name,
								parentPath,
								files: [],
							};

							entry.children.forEach((child) => {
								if (child.type === 'file') {
									newFiles.push(child.file);
									// frontend/src/components/folders/BatchUploadModal.jsx (continued)
									newFolderStructure[folderPath].files.push(child.file);
								}
							});

							// Process nested directories
							const nestedEntries = entry.children.filter(
								(child) => child.type === 'directory'
							);
							if (nestedEntries.length > 0) {
								processEntries(nestedEntries, folderPath);
							}
						}
					});
				};

				processEntries(entries);

				setFiles(newFiles);
				setFolderStructure(newFolderStructure);
			}
		},
		[processEntry]
	);

	// Handle drag events
	const handleDragIn = useCallback((e) => {
		e.preventDefault();
		e.stopPropagation();
		dragCounter.current++;
		if (e.dataTransfer.items && e.dataTransfer.items.length > 0) {
			dropAreaRef.current.classList.add(
				'border-ableton-blue-500',
				'bg-ableton-blue-500/10'
			);
		}
	}, []);

	const handleDragOut = useCallback((e) => {
		e.preventDefault();
		e.stopPropagation();
		dragCounter.current--;
		if (dragCounter.current === 0) {
			dropAreaRef.current.classList.remove(
				'border-ableton-blue-500',
				'bg-ableton-blue-500/10'
			);
		}
	}, []);

	const handleDragOver = useCallback((e) => {
		e.preventDefault();
		e.stopPropagation();
	}, []);

	// Set up drag and drop event listeners
	useEffect(() => {
		const div = dropAreaRef.current;
		if (div) {
			div.addEventListener('dragenter', handleDragIn);
			div.addEventListener('dragleave', handleDragOut);
			div.addEventListener('dragover', handleDragOver);
			div.addEventListener('drop', handleDrop);

			return () => {
				div.removeEventListener('dragenter', handleDragIn);
				div.removeEventListener('dragleave', handleDragOut);
				div.removeEventListener('dragover', handleDragOver);
				div.removeEventListener('drop', handleDrop);
			};
		}
	}, [handleDragIn, handleDragOut, handleDragOver, handleDrop]);

	// Upload files and create folder structure
	const handleUpload = async () => {
		if (files.length === 0) {
			setError('No audio files found to upload');
			return;
		}

		setUploading(true);
		setProgress(0);
		setError('');
		setUploadedCount(0);
		setCreatedFolders({});

		try {
			// First, create all necessary folders
			const folderPaths = Object.keys(folderStructure);
			const rootFolders = [];

			// Create folders starting with root level folders
			for (const path of folderPaths) {
				const folder = folderStructure[path];
				if (!folder.parentPath) {
					// This is a root folder
					try {
						const response = await api.createFolder(projectId, {
							name: folder.name,
							parent_folder_id: null,
						});

						const folderId = response.data.id;
						setCreatedFolders((prev) => ({
							...prev,
							[path]: folderId,
						}));

						rootFolders.push({ path, id: folderId });
					} catch (err) {
						console.error(`Error creating root folder ${folder.name}:`, err);
						setError(`Failed to create folder: ${folder.name}`);
						setUploading(false);
						return;
					}
				}
			}

			// Now create all child folders
			for (const path of folderPaths) {
				const folder = folderStructure[path];
				if (folder.parentPath && !createdFolders[path]) {
					const parentId = createdFolders[folder.parentPath];

					if (parentId) {
						try {
							const response = await api.createFolder(projectId, {
								name: folder.name,
								parent_folder_id: parentId,
							});

							const folderId = response.data.id;
							setCreatedFolders((prev) => ({
								...prev,
								[path]: folderId,
							}));
						} catch (err) {
							console.error(`Error creating folder ${folder.name}:`, err);
							// Continue even if one folder fails
						}
					}
				}
			}

			// Now upload all files to their respective folders
			const totalFiles = files.length;
			let successCount = 0;

			for (let i = 0; i < totalFiles; i++) {
				const file = files[i];
				const folderPath = file.webkitRelativePath
					? file.webkitRelativePath
					: '';
				let folderId;

				if (folderPath) {
					folderId = createdFolders[folderPath];
				} else {
					// File is at root, use the first root folder or create one
					if (rootFolders.length > 0) {
						folderId = rootFolders[0].id;
					} else {
						try {
							const response = await api.createFolder(projectId, {
								name: 'Uploads',
								parent_folder_id: null,
							});
							folderId = response.data.id;
							rootFolders.push({ path: 'Uploads', id: folderId });
						} catch (err) {
							console.error('Error creating default folder:', err);
							folderId = null;
						}
					}
				}

				if (folderId) {
					try {
						const formData = new FormData();
						formData.append('file', file);
						formData.append('filename', file.name);

						await api.createAudioFile(projectId, folderId, formData);
						successCount++;
					} catch (err) {
						console.error(`Error uploading file ${file.name}:`, err);
						// Continue even if one file fails
					}
				}

				setUploadedCount(i + 1);
				setProgress(Math.round(((i + 1) / totalFiles) * 100));
			}

			if (successCount > 0) {
				// At least some files were uploaded successfully
				if (onUploadComplete) {
					onUploadComplete(successCount, totalFiles);
				}
			} else {
				setError('Failed to upload any files');
			}
		} catch (err) {
			console.error('Error during batch upload:', err);
			setError('An error occurred during the upload process');
		} finally {
			setUploading(false);
		}
	};

	return (
		<div className='fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50'>
			<div className='bg-ableton-dark-300 rounded-md shadow-xl w-full max-w-2xl'>
				<div className='flex justify-between items-center p-4 border-b border-ableton-dark-200'>
					<h2 className='text-xl font-medium flex items-center'>
						<FiUpload className='mr-2' /> Batch Upload Music Files
					</h2>

					<button
						onClick={onClose}
						className='text-gray-400 hover:text-white transition-colors'
						disabled={uploading}
					>
						<FiX className='w-5 h-5' />
					</button>
				</div>

				<div className='p-4'>
					{error && (
						<div className='mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-md text-red-500 text-sm'>
							{error}
						</div>
					)}

					{!uploading ? (
						<>
							<div
								ref={dropAreaRef}
								className='border-2 border-dashed rounded-md p-8 flex flex-col items-center justify-center mb-4 transition-colors border-ableton-dark-100 hover:border-ableton-dark-50 cursor-pointer'
							>
								{files.length === 0 ? (
									<>
										<FiUpload className='w-12 h-12 text-gray-400 mb-3' />
										<h3 className='font-medium text-lg mb-2'>
											Drag & Drop Folder or Files
										</h3>
										<p className='text-center text-gray-400 max-w-md'>
											Drag a folder to preserve its structure or drop individual
											audio files.
											<br />
											Supported formats: MP3, WAV, AIFF, FLAC, M4A, OGG, WMA
										</p>
									</>
								) : (
									<>
										<FiFolder className='w-12 h-12 text-ableton-blue-400 mb-3' />
										<h3 className='font-medium text-lg mb-2'>
											Files Ready for Upload
										</h3>
										<p className='text-center text-gray-400'>
											{files.length} audio file{files.length !== 1 ? 's' : ''}{' '}
											selected
											{Object.keys(folderStructure).length > 0 && (
												<>
													<br />
													in {Object.keys(folderStructure).length} folder
													{Object.keys(folderStructure).length !== 1 ? 's' : ''}
												</>
											)}
										</p>
									</>
								)}
							</div>

							{files.length > 0 && (
								<div className='mb-4 max-h-60 overflow-y-auto border border-ableton-dark-200 rounded-md bg-ableton-dark-400 p-2'>
									<div className='mb-2 px-2 text-sm text-gray-400'>
										Selected Files:
									</div>

									{Object.keys(folderStructure).length > 0 ? (
										// Display folder structure
										<div className='space-y-2'>
											{Object.keys(folderStructure)
												.filter((path) => !folderStructure[path].parentPath)
												.map((path) => (
													<div
														key={path}
														className='pl-2'
													>
														<div className='flex items-center text-ableton-blue-400 font-medium'>
															<FiFolder className='mr-1' />{' '}
															{folderStructure[path].name}
															<span className='ml-2 text-xs text-gray-500'>
																({folderStructure[path].files.length} file
																{folderStructure[path].files.length !== 1
																	? 's'
																	: ''}
																)
															</span>
														</div>

														{/* Display files in this folder */}
														<div className='pl-4 mt-1 space-y-1'>
															{folderStructure[path].files.map((file) => (
																<div
																	key={file.name}
																	className='flex items-center text-sm text-gray-300'
																>
																	<FiFile className='mr-1 text-gray-500' />{' '}
																	{file.name}
																</div>
															))}
														</div>

														{/* Display nested folders */}
														{Object.keys(folderStructure)
															.filter(
																(childPath) =>
																	folderStructure[childPath].parentPath === path
															)
															.map((childPath) => (
																<div
																	key={childPath}
																	className='pl-4 mt-1'
																>
																	<div className='flex items-center text-ableton-blue-300 font-medium'>
																		<FiFolder className='mr-1' />{' '}
																		{folderStructure[childPath].name}
																		<span className='ml-2 text-xs text-gray-500'>
																			({folderStructure[childPath].files.length}{' '}
																			file
																			{folderStructure[childPath].files
																				.length !== 1
																				? 's'
																				: ''}
																			)
																		</span>
																	</div>

																	{/* Display files in this subfolder */}
																	<div className='pl-4 mt-1 space-y-1'>
																		{folderStructure[childPath].files.map(
																			(file) => (
																				<div
																					key={file.name}
																					className='flex items-center text-sm text-gray-300'
																				>
																					<FiFile className='mr-1 text-gray-500' />{' '}
																					{file.name}
																				</div>
																			)
																		)}
																	</div>
																</div>
															))}
													</div>
												))}
										</div>
									) : (
										// Just display list of files
										<div className='space-y-1 px-2'>
											{files.map((file) => (
												<div
													key={file.name}
													className='flex items-center text-sm'
												>
													<FiFile className='mr-2 text-gray-500' /> {file.name}
												</div>
											))}
										</div>
									)}
								</div>
							)}

							<div className='flex space-x-3'>
								<button
									type='button'
									onClick={onClose}
									className='flex-1 py-3 bg-ableton-dark-200 hover:bg-ableton-dark-100 text-white rounded-md transition-colors'
								>
									Cancel
								</button>

								<button
									type='button'
									onClick={handleUpload}
									disabled={files.length === 0}
									className={`flex-1 py-3 rounded-md transition-colors ${
										files.length === 0
											? 'bg-ableton-dark-200 text-gray-500 cursor-not-allowed'
											: 'bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white'
									}`}
								>
									Upload {files.length} File{files.length !== 1 ? 's' : ''}
								</button>
							</div>
						</>
					) : (
						// Upload progress view
						<div className='py-6'>
							<div className='flex justify-between items-center mb-2'>
								<span>Uploading files...</span>
								<span className='text-sm text-gray-400'>
									{uploadedCount} of {files.length} ({progress}%)
								</span>
							</div>

							<div className='w-full h-2 bg-ableton-dark-200 rounded-full overflow-hidden mb-6'>
								<div
									className='h-full bg-ableton-blue-500 rounded-full'
									style={{ width: `${progress}%` }}
								></div>
							</div>

							<div className='text-center text-sm text-gray-400'>
								Please don't close this window until the upload is complete.
							</div>
						</div>
					)}
				</div>

				{/* Upload Complete View */}
				{!uploading && uploadedCount > 0 && (
					<div className='p-4 border-t border-ableton-dark-200 bg-ableton-dark-400/50'>
						<div className='flex items-center text-green-400 mb-2'>
							<FiCheck className='mr-2' /> Upload Complete
						</div>

						<p className='text-sm text-gray-400'>
							Successfully uploaded {uploadedCount} of {files.length} files.
							{uploadedCount < files.length && (
								<span className='text-yellow-400 ml-1'>
									Some files couldn't be uploaded. Check the console for
									details.
								</span>
							)}
						</p>

						<button
							onClick={onClose}
							className='mt-3 px-4 py-2 bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white rounded-md transition-colors'
						>
							Done
						</button>
					</div>
				)}
			</div>
		</div>
	);
};

export default BatchUploadModal;
