// frontend/src/components/folders/FolderBrowser.jsx
import React, { useState, useEffect } from 'react';
import {
	FiFolder,
	FiMusic,
	FiPlay,
	FiPause,
	FiDownload,
	FiTrash2,
	FiPlus,
} from 'react-icons/fi';
import api from '../../services/api';
import DeleteConfirmModal from '../common/DeleteConfirmModal';

const FolderBrowser = ({ projectId, folderId, onSelectFolder }) => {
	const [currentFolder, setCurrentFolder] = useState(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [path, setPath] = useState([]);
	const [subfolders, setSubfolders] = useState([]);
	const [audioFiles, setAudioFiles] = useState([]);
	const [playingFile, setPlayingFile] = useState(null);
	const [deleteModal, setDeleteModal] = useState({
		show: false,
		type: null,
		item: null,
	});

	const audioRef = React.useRef(new Audio());

	useEffect(() => {
		if (folderId) {
			fetchFolder(folderId);
		} else {
			fetchRootFolders();
		}

		// Clean up audio on unmount
		return () => {
			if (audioRef.current) {
				audioRef.current.pause();
				audioRef.current.src = '';
			}
		};
	}, [projectId, folderId]);

	// Effect for audio playback
	useEffect(() => {
		const audio = audioRef.current;

		if (playingFile) {
			audio.src = playingFile.file_url;
			audio.play().catch((err) => console.error('Error playing audio:', err));

			audio.onended = () => {
				setPlayingFile(null);
			};
		} else {
			audio.pause();
		}

		return () => {
			audio.onended = null;
		};
	}, [playingFile]);

	const fetchRootFolders = async () => {
		try {
			setLoading(true);
			const response = await api.getRootFolders(projectId);
			setSubfolders(response.data);
			setAudioFiles([]);
			setCurrentFolder(null);
			setPath([]);
			setError(null);
		} catch (err) {
			console.error('Error fetching root folders:', err);
			setError('Failed to load folders');
		} finally {
			setLoading(false);
		}
	};

	const fetchFolder = async (id) => {
		try {
			setLoading(true);
			const response = await api.getFolder(projectId, id);
			const folder = response.data;

			setCurrentFolder(folder);
			setSubfolders(folder.subfolders || []);
			setAudioFiles(folder.audio_files || []);

			// Update path
			if (folder.parent_folder_id) {
				// We need to get the full path
				let currentId = folder.parent_folder_id;
				let pathArray = [folder];

				while (currentId) {
					const parentResponse = await api.getFolder(projectId, currentId);
					const parentFolder = parentResponse.data;
					pathArray.unshift(parentFolder);
					currentId = parentFolder.parent_folder_id;
				}

				setPath(pathArray);
			} else {
				setPath([folder]);
			}

			setError(null);
		} catch (err) {
			console.error('Error fetching folder:', err);
			setError('Failed to load folder');
		} finally {
			setLoading(false);
		}
	};

	const handleFolderClick = (folder) => {
		fetchFolder(folder.id);
		if (onSelectFolder) {
			onSelectFolder(folder);
		}
	};

	const handlePathClick = (index) => {
		if (index === -1) {
			// Root level
			fetchRootFolders();
		} else {
			const folder = path[index];
			fetchFolder(folder.id);
		}
	};

	const togglePlayAudio = (file) => {
		if (playingFile && playingFile.id === file.id) {
			setPlayingFile(null);
		} else {
			setPlayingFile(file);
		}
	};

	const handleDownloadAudio = (file) => {
		// Create a temporary link element and trigger the download
		const link = document.createElement('a');
		link.href = file.file_url;
		link.download = file.filename;
		document.body.appendChild(link);
		link.click();
		document.body.removeChild(link);
	};

	const handleDeleteClick = (type, item) => {
		setDeleteModal({
			show: true,
			type,
			item,
		});
	};

	const handleConfirmDelete = async () => {
		const { type, item } = deleteModal;

		try {
			if (type === 'folder') {
				await api.deleteFolder(projectId, item.id);
				setSubfolders((prev) => prev.filter((f) => f.id !== item.id));
			} else if (type === 'file') {
				await api.deleteAudioFile(projectId, currentFolder.id, item.id);
				setAudioFiles((prev) => prev.filter((f) => f.id !== item.id));
			}
		} catch (err) {
			console.error(`Error deleting ${type}:`, err);
			setError(`Failed to delete ${type}`);
		} finally {
			setDeleteModal({ show: false, type: null, item: null });
		}
	};

	if (loading && !currentFolder && !subfolders.length) {
		return <div className='flex justify-center py-8'>Loading...</div>;
	}

	if (error) {
		return <div className='text-red-500 py-8'>{error}</div>;
	}

	return (
		<div className='bg-ableton-dark-300 rounded-lg border border-ableton-dark-200 p-4'>
			{/* Breadcrumb navigation */}
			<div className='flex items-center mb-4 overflow-x-auto whitespace-nowrap py-2'>
				<button
					className='text-ableton-blue-400 hover:text-ableton-blue-300 px-2 py-1 rounded'
					onClick={() => handlePathClick(-1)}
				>
					Root
				</button>

				{path.map((folder, index) => (
					<React.Fragment key={folder.id}>
						<span className='mx-2 text-gray-500'>/</span>
						<button
							className={`px-2 py-1 rounded ${
								index === path.length - 1
									? 'text-white font-medium'
									: 'text-ableton-blue-400 hover:text-ableton-blue-300'
							}`}
							onClick={() => handlePathClick(index)}
						>
							{folder.name}
						</button>
					</React.Fragment>
				))}
			</div>

			{/* Content area */}
			<div className='border border-ableton-dark-200 rounded-md bg-ableton-dark-400 p-2'>
				{/* Subfolders */}
				{subfolders.length > 0 && (
					<div className='mb-4'>
						<h4 className='text-sm text-gray-400 mb-2 px-2'>Folders</h4>

						<div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2'>
							{subfolders.map((folder) => (
								<div
									key={folder.id}
									className='flex items-center justify-between p-3 bg-ableton-dark-300 rounded-md hover:bg-ableton-dark-200 cursor-pointer group'
									onClick={() => handleFolderClick(folder)}
								>
									<div className='flex items-center'>
										<FiFolder className='mr-2 text-ableton-blue-400' />
										<span>{folder.name}</span>
									</div>

									<button
										className='text-gray-500 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity'
										onClick={(e) => {
											e.stopPropagation();
											handleDeleteClick('folder', folder);
										}}
									>
										<FiTrash2 size={16} />
									</button>
								</div>
							))}
						</div>
					</div>
				)}

				{/* Audio files */}
				{audioFiles.length > 0 && (
					<div>
						<h4 className='text-sm text-gray-400 mb-2 px-2'>Audio Files</h4>

						<div className='space-y-2'>
							{audioFiles.map((file) => (
								<div
									key={file.id}
									className='flex items-center justify-between p-3 bg-ableton-dark-300 rounded-md hover:bg-ableton-dark-200 group'
								>
									<div className='flex items-center flex-grow'>
										<button
											className='mr-3 w-8 h-8 flex items-center justify-center rounded-full bg-ableton-blue-500 hover:bg-ableton-blue-600 transition-colors'
											onClick={() => togglePlayAudio(file)}
										>
											{playingFile && playingFile.id === file.id ? (
												<FiPause size={16} />
											) : (
												<FiPlay size={16} />
											)}
										</button>

										<div className='min-w-0'>
											<div className='font-medium truncate'>
												{file.filename}
											</div>
											<div className='text-xs text-gray-400 flex'>
												<span className='mr-3'>
													{file.file_type?.split('/')[1]?.toUpperCase() ||
														'AUDIO'}
												</span>
												<span>
													{(file.file_size / 1024 / 1024).toFixed(2)} MB
												</span>
												{file.duration && (
													<span className='ml-3'>
														{Math.floor(file.duration / 60)}:
														{String(Math.floor(file.duration % 60)).padStart(
															2,
															'0'
														)}
													</span>
												)}
											</div>
										</div>
									</div>

									<div className='flex space-x-2 opacity-0 group-hover:opacity-100 transition-opacity'>
										<button
											className='text-gray-400 hover:text-white p-1'
											onClick={() => handleDownloadAudio(file)}
										>
											<FiDownload size={16} />
										</button>

										<button
											className='text-gray-400 hover:text-red-400 p-1'
											onClick={() => handleDeleteClick('file', file)}
										>
											<FiTrash2 size={16} />
										</button>
									</div>
								</div>
							))}
						</div>
					</div>
				)}

				{/* Empty state */}
				{subfolders.length === 0 && audioFiles.length === 0 && (
					<div className='text-center py-8 text-gray-500'>
						<p className='mb-2'>This folder is empty.</p>
						<div className='flex justify-center space-x-2'>
							<button className='text-ableton-blue-400 hover:text-ableton-blue-300 flex items-center'>
								<FiFolder className='mr-1' /> Create Folder
							</button>
							<button className='text-ableton-blue-400 hover:text-ableton-blue-300 flex items-center'>
								<FiMusic className='mr-1' /> Upload Files
							</button>
						</div>
					</div>
				)}
			</div>

			{/* Delete confirmation modal */}
			{deleteModal.show && (
				<DeleteConfirmModal
					show={deleteModal.show}
					onClose={() =>
						setDeleteModal({ show: false, type: null, item: null })
					}
					onConfirm={handleConfirmDelete}
					title={`Delete ${deleteModal.type === 'folder' ? 'Folder' : 'File'}`}
					message={`Are you sure you want to delete this ${deleteModal.type}${
						deleteModal.type === 'folder' ? ' and all its contents' : ''
					}? This action cannot be undone.`}
					confirmText={`Delete ${deleteModal.type}`}
				/>
			)}
		</div>
	);
};

export default FolderBrowser;
