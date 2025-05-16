// frontend/src/components/projects/CreateVersionModal.jsx
import React, { useState } from 'react';
import { FiX } from 'react-icons/fi';

const CreateVersionModal = ({ show, onClose, onCreate, projectId }) => {
	const [title, setTitle] = useState('');
	const [description, setDescription] = useState('');
	const [loading, setLoading] = useState(false);

	if (!show) return null;

	const handleSubmit = async (e) => {
		e.preventDefault();

		if (!title) return;

		setLoading(true);

		try {
			await onCreate({
				title,
				description,
				project_id: projectId,
			});

			// Reset form
			setTitle('');
			setDescription('');
		} catch (error) {
			console.error('Error creating version:', error);
		} finally {
			setLoading(false);
		}
	};

	return (
		<div className='fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50'>
			<div className='bg-ableton-dark-300 rounded-md shadow-xl w-full max-w-md'>
				<div className='flex justify-between items-center p-4 border-b border-ableton-dark-200'>
					<h2 className='text-xl font-medium'>Create New Version</h2>

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
					<div className='mb-4'>
						<label className='block text-sm text-gray-400 mb-1'>
							Version Title <span className='text-red-500'>*</span>
						</label>
						<input
							type='text'
							value={title}
							onChange={(e) => setTitle(e.target.value)}
							placeholder='e.g., Initial Demo, Mix v1, Mastered Version'
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
							required
						/>
					</div>

					<div className='mb-4'>
						<label className='block text-sm text-gray-400 mb-1'>
							Description (optional)
						</label>
						<textarea
							value={description}
							onChange={(e) => setDescription(e.target.value)}
							placeholder="Describe what's new or changed in this version..."
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all min-h-[100px]'
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
							disabled={!title || loading}
							className={`flex-1 py-3 rounded-md transition-colors ${
								title && !loading
									? 'bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white'
									: 'bg-ableton-dark-200 text-gray-500 cursor-not-allowed'
							}`}
						>
							{loading ? 'Creating...' : 'Create Version'}
						</button>
					</div>
				</form>
			</div>
		</div>
	);
};

export default CreateVersionModal;
