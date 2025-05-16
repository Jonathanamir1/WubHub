// frontend/src/components/projects/ProjectForm.jsx
import React, { useState } from 'react';
import { FiAlertCircle } from 'react-icons/fi';
import Spinner from '../common/Spinner';

const ProjectForm = ({ initialData, onSubmit, loading, error }) => {
	const [formData, setFormData] = useState({
		title: initialData?.title || '',
		description: initialData?.description || '',
		visibility: initialData?.visibility || 'private',
	});

	const handleChange = (e) => {
		const { name, value } = e.target;
		setFormData((prev) => ({
			...prev,
			[name]: value,
		}));
	};

	const handleSubmit = (e) => {
		e.preventDefault();
		onSubmit(formData);
	};

	return (
		<form onSubmit={handleSubmit}>
			{error && (
				<div className='mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-md text-red-500 text-sm flex items-start'>
					<FiAlertCircle className='mr-2 mt-0.5 flex-shrink-0' />
					<span>{error}</span>
				</div>
			)}

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
					value={formData.title}
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
					value={formData.description}
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
					value={formData.visibility}
					onChange={handleChange}
					className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 transition-all'
				>
					<option value='private'>Private</option>
					<option value='public'>Public</option>
				</select>
				<p className='mt-1 text-xs text-gray-500'>
					{formData.visibility === 'private'
						? 'Only you and collaborators can access this project'
						: 'Anyone with the link can view this project'}
				</p>
			</div>

			<button
				type='submit'
				disabled={loading}
				className='w-full py-3 bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white rounded-md transition-colors flex items-center justify-center'
			>
				{loading ? (
					<>
						<Spinner
							size='sm'
							color='white'
							className='mr-2'
						/>
						{initialData ? 'Updating...' : 'Creating...'}
					</>
				) : (
					`${initialData ? 'Update' : 'Create'} Project`
				)}
			</button>
		</form>
	);
};

export default ProjectForm;
