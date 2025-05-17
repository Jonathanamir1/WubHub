// frontend/src/components/folders/FolderUploadModal.jsx
import React, { useState } from 'react';
import { FiX, FiFolder } from 'react-icons/fi';
import api from '../../services/api';

const FolderUploadModal = ({
	projectId,
	parentFolderId,
	onClose,
	onFolderCreated,
}) => {
	const [folderName, setFolderName] = useState('');
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState('');

	const handleSubmit = async (e) => {
		e.preventDefault();

		if (!folderName.trim()) {
			setError('Folder name is required');
			return;
		}

		setLoading(true);
		setError('');

		try {
			const response = await api.createFolder(projectId, {
				name: folderName,
				parent_folder_id: parentFolderId || null,
			});

			onFolderCreated(response.data);
			onClose();
		} catch (err) {
			console.error('Error creating folder:', err);
			setError(err.response?.data?.errors?.[0] || 'Failed to create folder');
		} finally {
			setLoading(false);
		}
	};

	return (
		<div className='fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50'>
			<div className='bg-ableton-dark-300 rounded-md shadow-xl w-full max-w-md'>
				<div className='flex justify-between items-center p-4 border-b border-ableton-dark-200'>
					<h2 className='text-xl font-medium flex items-center'>
						<FiFolder className='mr-2' /> Create New Folder
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
						<label
							htmlFor='folderName'
							className='block text-sm text-gray-400 mb-1.5'
						>
							Folder Name <span className='text-red-500'>*</span>
						</label>
						<input
							type='text'
							id='folderName'
							value={folderName}
							onChange={(e) => setFolderName(e.target.value)}
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
							placeholder='My Folder'
							required
						/>
					</div>

					<div className='flex space-x-3'>
						<button
							type='button'
							onClick={onClose}
							className='flex-1 py-3 bg-ableton-dark-200 hover:bg-ableton-dark-100 text-white rounded-md transition-colors'
						>
							Cancel
						</button>

						<button
							type='submit'
							disabled={loading || !folderName.trim()}
							className={`flex-1 py-3 rounded-md transition-colors ${
								loading || !folderName.trim()
									? 'bg-ableton-dark-200 text-gray-500 cursor-not-allowed'
									: 'bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white'
							}`}
						>
							{loading ? 'Creating...' : 'Create Folder'}
						</button>
					</div>
				</form>
			</div>
		</div>
	);
};

export default FolderUploadModal;
