// frontend/src/components/folders/FolderManager.jsx
import React, { useState, useEffect } from 'react';
import {
	FiFolder,
	FiFile,
	FiPlus,
	FiChevronRight,
	FiChevronDown,
	FiTrash2,
	FiUpload,
} from 'react-icons/fi';
import api from '../../services/api';
import FolderUploadModal from './FolderUploadModal';
import AudioFileUploadModal from './AudioFileUploadModal';
import BatchUploadModal from './BatchUploadModal';

const FolderManager = ({ projectId }) => {
	const [folders, setFolders] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [expandedFolders, setExpandedFolders] = useState({});
	const [currentFolder, setCurrentFolder] = useState(null);
	const [showFolderUploadModal, setShowFolderUploadModal] = useState(false);
	const [showFileUploadModal, setShowFileUploadModal] = useState(false);
	const [showBatchUploadModal, setShowBatchUploadModal] = useState(false);

	useEffect(() => {
		fetchRootFolders();
	}, [projectId]);

	const fetchRootFolders = async () => {
		try {
			setLoading(true);
			const response = await api.getRootFolders(projectId);
			setFolders(response.data);
			setError(null);
		} catch (err) {
			console.error('Error fetching folders:', err);
			setError('Failed to load folders');
		} finally {
			setLoading(false);
		}
	};

	const toggleFolder = async (folderId) => {
		const isExpanded = expandedFolders[folderId];

		if (!isExpanded) {
			// Load subfolders if expanding
			try {
				const response = await api.getFolder(projectId, folderId);
				// Update the folder in our folders array
				setFolders((prevFolders) =>
					prevFolders.map((folder) =>
						folder.id === folderId
							? {
									...folder,
									subfolders: response.data.subfolders,
									audio_files: response.data.audio_files,
							  }
							: folder
					)
				);
			} catch (err) {
				console.error('Error fetching folder contents:', err);
			}
		}

		setExpandedFolders((prev) => ({
			...prev,
			[folderId]: !isExpanded,
		}));
	};

	const handleCreateFolder = () => {
		setShowFolderUploadModal(true);
	};

	const handleUploadFiles = () => {
		setShowFileUploadModal(true);
	};

	const handleBatchUploadComplete = (successCount, totalCount) => {
		fetchRootFolders(); // Refresh the folder list
	};

	const handleFolderCreated = (newFolder) => {
		if (newFolder.parent_folder_id) {
			// Add to parent's subfolders
			setFolders((prevFolders) =>
				prevFolders.map((folder) =>
					folder.id === newFolder.parent_folder_id
						? {
								...folder,
								subfolders: [...(folder.subfolders || []), newFolder],
						  }
						: folder
				)
			);
		} else {
			// Add to root folders
			setFolders((prevFolders) => [...prevFolders, newFolder]);
		}
	};

	const handleAudioFileUploaded = (newFile) => {
		// Add the file to the appropriate folder
		setFolders((prevFolders) =>
			prevFolders.map((folder) =>
				folder.id === newFile.folder_id
					? {
							...folder,
							audio_files: [...(folder.audio_files || []), newFile],
					  }
					: folder
			)
		);
	};

	if (loading) {
		return <div className='flex justify-center py-8'>Loading...</div>;
	}

	if (error) {
		return <div className='text-red-500 py-8'>{error}</div>;
	}

	const renderFileTree = (foldersList, depth = 0) => {
		return foldersList.map((folder) => (
			<div
				key={folder.id}
				style={{ marginLeft: `${depth * 20}px` }}
			>
				<div
					className='flex items-center py-2 px-3 hover:bg-ableton-dark-200 rounded-md cursor-pointer'
					onClick={() => toggleFolder(folder.id)}
				>
					<span className='mr-2'>
						{folder.subfolders && folder.subfolders.length > 0 ? (
							expandedFolders[folder.id] ? (
								<FiChevronDown />
							) : (
								<FiChevronRight />
							)
						) : (
							<span className='w-4'></span> // Spacer
						)}
					</span>
					<FiFolder className='mr-2 text-ableton-blue-400' />
					<span>{folder.name}</span>
				</div>

				{expandedFolders[folder.id] && (
					<>
						{/* Render audio files in this folder */}
						{folder.audio_files &&
							folder.audio_files.map((file) => (
								<div
									key={file.id}
									className='flex items-center py-2 px-3 hover:bg-ableton-dark-200 rounded-md cursor-pointer'
									style={{ marginLeft: `${(depth + 1) * 20}px` }}
								>
									<span className='w-4 mr-2'></span> {/* Spacer */}
									<FiFile className='mr-2 text-gray-400' />
									<span>{file.filename}</span>
								</div>
							))}

						{/* Render subfolders recursively */}
						{folder.subfolders && renderFileTree(folder.subfolders, depth + 1)}
					</>
				)}
			</div>
		));
	};

	return (
		<div className='bg-ableton-dark-300 rounded-lg border border-ableton-dark-200 p-4'>
			<div className='flex justify-between items-center mb-4'>
				<h3 className='text-lg font-medium'>Folders & Files</h3>

				<div className='flex space-x-2'>
					<button
						onClick={handleCreateFolder}
						className='flex items-center px-3 py-1.5 bg-ableton-dark-200 hover:bg-ableton-dark-100 rounded-md text-sm transition-colors'
					>
						<FiFolder className='mr-1.5' /> New Folder
					</button>

					<button
						onClick={handleUploadFiles}
						className='flex items-center px-3 py-1.5 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md text-sm transition-colors'
					>
						<FiUpload className='mr-1.5' /> Upload Files
					</button>

					<button
						onClick={() => setShowBatchUploadModal(true)}
						className='flex items-center px-3 py-1.5 bg-green-500 hover:bg-green-600 rounded-md text-sm transition-colors'
					>
						<FiUpload className='mr-1.5' /> Batch Upload
					</button>
				</div>
			</div>

			<div className='border border-ableton-dark-200 rounded-md bg-ableton-dark-400 p-2 max-h-80 overflow-y-auto'>
				{folders.length === 0 ? (
					<div className='text-center py-8 text-gray-500'>
						No folders yet. Create a folder to get started.
					</div>
				) : (
					renderFileTree(folders)
				)}
			</div>

			{showFolderUploadModal && (
				<FolderUploadModal
					projectId={projectId}
					parentFolderId={currentFolder?.id}
					onClose={() => setShowFolderUploadModal(false)}
					onFolderCreated={handleFolderCreated}
				/>
			)}

			{showFileUploadModal && (
				<AudioFileUploadModal
					projectId={projectId}
					folderId={currentFolder?.id || folders[0]?.id}
					folders={folders}
					onClose={() => setShowFileUploadModal(false)}
					onFileUploaded={handleAudioFileUploaded}
				/>
			)}

			{showBatchUploadModal && (
				<BatchUploadModal
					projectId={projectId}
					onClose={() => setShowBatchUploadModal(false)}
					onUploadComplete={handleBatchUploadComplete}
				/>
			)}
		</div>
	);
};

export default FolderManager;
