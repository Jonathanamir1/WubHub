// frontend/src/components/projects/CreateProjectModal.jsx
import React, { useState } from 'react';
import { FiX } from 'react-icons/fi';
import api from '../../services/api';
import Spinner from '../common/Spinner';

const CreateProjectModal = ({
	workspaceId,
	isOpen,
	onClose,
	onProjectCreated,
}) => {
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState(null);
	const [projectData, setProjectData] = useState({
		title: '',
		description: '',
		visibility: 'private',
	});

	if (!isOpen) return null;

	const handleChange = (e) => {
		const { name, value } = e.target;
		setProjectData((prev) => ({
			...prev,
			[name]: value,
		}));
	};

	const handleSubmit = async (e) => {
		e.preventDefault();
		setLoading(true);
		setError(null);

		try {
			const response = await api.createProject(workspaceId, projectData);
			onProjectCreated(response.data);
			onClose();
		} catch (err) {
			console.error('Error creating project:', err);
			setError(err.response?.data?.errors?.[0] || 'Failed to create project');
		} finally {
			setLoading(false);
		}
	};

	return (
		<div className='fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50'>
			<div className='bg-ableton-dark-300 rounded-xl w-full max-w-md shadow-2xl'>
				<div className='flex justify-between items-center p-6 border-b border-ableton-dark-200'>
					<h2 className='text-xl font-semibold text-white'>
						Create New Project
					</h2>
					<button
						onClick={onClose}
						className='text-gray-400 hover:text-white transition-colors'
					>
						<FiX className='w-6 h-6' />
					</button>
				</div>

				{error && (
					<div className='mx-6 mt-4 p-3 bg-red-500/10 border border-red-500/30 rounded-md text-red-500 text-sm'>
						{error}
					</div>
				)}

				<form
					onSubmit={handleSubmit}
					className='p-6'
				>
					<div className='mb-4'>
						<label
							htmlFor='title'
							className='block text-sm text-gray-400 mb-1.5'
						>
							Project Title <span className='text-red-500'>*</span>
						</label>
						<input
							type='text'
							id='title'
							name='title'
							value={projectData.title}
							onChange={handleChange}
							placeholder='My New Project'
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
							required
						/>
					</div>

					<div className='mb-4'>
						<label
							htmlFor='description'
							className='block text-sm text-gray-400 mb-1.5'
						>
							Description
						</label>
						<textarea
							id='description'
							name='description'
							value={projectData.description}
							onChange={handleChange}
							placeholder='What is this project about?'
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all min-h-[100px]'
						></textarea>
					</div>

					<div className='mb-6'>
						<label
							htmlFor='visibility'
							className='block text-sm text-gray-400 mb-1.5'
						>
							Visibility
						</label>
						<select
							id='visibility'
							name='visibility'
							value={projectData.visibility}
							onChange={handleChange}
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 transition-all'
						>
							<option value='private'>Private</option>
							<option value='public'>Public</option>
						</select>
						<p className='mt-1 text-xs text-gray-500'>
							{projectData.visibility === 'private'
								? 'Only you and collaborators can access this project'
								: 'Anyone with the link can view this project'}
						</p>
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
							disabled={loading}
							className='flex-1 py-3 bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white rounded-md transition-colors flex items-center justify-center'
						>
							{loading ? (
								<>
									<Spinner
										size='sm'
										color='white'
										className='mr-2'
									/>
									Creating...
								</>
							) : (
								'Create Project'
							)}
						</button>
					</div>
				</form>
			</div>
		</div>
	);
};

export default CreateProjectModal;
