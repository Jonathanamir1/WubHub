// frontend/src/components/workspaces/RenameWorkspaceModal.jsx
import React, { useState, useEffect, useRef } from 'react';
import { FiX } from 'react-icons/fi';
import api from '../../services/api';
import Spinner from '../common/Spinner';

const RenameWorkspaceModal = ({ onClose, onWorkspaceRenamed, workspace }) => {
	const [name, setName] = useState(workspace?.name || '');
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState(null);
	const inputRef = useRef(null);

	// Focus input on mount
	useEffect(() => {
		if (inputRef.current) {
			inputRef.current.focus();
			inputRef.current.select();
		}
	}, []);

	const handleSubmit = async (e) => {
		e.preventDefault();

		if (!name.trim()) {
			setError('Workspace name cannot be empty');
			return;
		}

		try {
			setLoading(true);
			setError(null);

			const response = await api.updateWorkspace(workspace.id, { name });

			onWorkspaceRenamed(response.data);
			onClose();
		} catch (err) {
			console.error('Error renaming workspace:', err);
			setError(err.response?.data?.error || 'Failed to rename workspace');
		} finally {
			setLoading(false);
		}
	};

	// Handle escape key
	useEffect(() => {
		const handleEsc = (event) => {
			if (event.key === 'Escape') {
				onClose();
			}
		};

		window.addEventListener('keydown', handleEsc);

		return () => {
			window.removeEventListener('keydown', handleEsc);
		};
	}, [onClose]);

	return (
		<div className='fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4'>
			<div className='bg-ableton-dark-300 rounded-lg shadow-xl w-full max-w-md'>
				<div className='flex justify-between items-center p-4 border-b border-ableton-dark-200'>
					<h2 className='text-xl font-semibold text-white'>Rename Workspace</h2>
					<button
						onClick={onClose}
						className='text-gray-400 hover:text-white transition-colors'
						aria-label='Close'
					>
						<FiX className='w-5 h-5' />
					</button>
				</div>

				<form onSubmit={handleSubmit}>
					<div className='p-4'>
						<div className='mb-4'>
							<label
								htmlFor='workspace-name'
								className='block text-sm font-medium text-gray-300 mb-1'
							>
								Workspace Name
							</label>
							<input
								ref={inputRef}
								type='text'
								id='workspace-name'
								className='w-full px-3 py-2 rounded-md bg-ableton-dark-200 border border-ableton-dark-100 text-white focus:outline-none focus:ring-1 focus:ring-ableton-blue-500'
								value={name}
								onChange={(e) => setName(e.target.value)}
								placeholder='Enter workspace name'
							/>
						</div>

						{error && <div className='mb-4 text-red-400 text-sm'>{error}</div>}
					</div>

					<div className='p-4 bg-ableton-dark-200 rounded-b-lg flex justify-end space-x-2'>
						<button
							type='button'
							onClick={onClose}
							className='px-4 py-2 rounded-md border border-ableton-dark-100 text-gray-300 hover:bg-ableton-dark-300 transition-colors'
							disabled={loading}
						>
							Cancel
						</button>
						<button
							type='submit'
							className='px-4 py-2 rounded-md bg-ableton-blue-500 text-white hover:bg-ableton-blue-600 transition-colors flex items-center'
							disabled={loading}
						>
							{loading ? (
								<>
									<Spinner
										size='sm'
										className='mr-2'
									/>
									Renaming...
								</>
							) : (
								'Rename'
							)}
						</button>
					</div>
				</form>
			</div>
		</div>
	);
};

export default RenameWorkspaceModal;
