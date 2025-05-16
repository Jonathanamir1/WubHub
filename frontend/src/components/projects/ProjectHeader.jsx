// frontend/src/components/projects/ProjectHeader.jsx
import React from 'react';
import { FiEdit, FiTrash2, FiClock } from 'react-icons/fi';

const ProjectHeader = ({ project, isOwner, onEdit, onDelete }) => {
	if (!project) return null;

	const formatDate = (dateString) => {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'long',
			day: 'numeric',
		});
	};

	return (
		<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200'>
			<div className='flex flex-col md:flex-row justify-between items-start'>
				<div>
					<h1 className='text-2xl font-bold'>{project.title}</h1>

					<div className='flex items-center mt-1 space-x-3'>
						<span className='bg-ableton-blue-500/20 text-ableton-blue-300 border border-ableton-blue-500/30 px-2 py-0.5 rounded-full text-xs'>
							{project.visibility}
						</span>

						<span className='text-gray-400 text-sm flex items-center'>
							<FiClock className='mr-1 w-3 h-3' /> Created{' '}
							{formatDate(project.created_at)}
						</span>
					</div>

					{project.description && (
						<p className='mt-3 text-gray-300'>{project.description}</p>
					)}
				</div>

				{isOwner && (
					<div className='flex mt-3 md:mt-0'>
						<button
							onClick={onEdit}
							className='flex items-center px-3 py-1.5 bg-ableton-dark-200 hover:bg-ableton-dark-100 rounded-md text-sm mr-2 transition-colors'
						>
							<FiEdit className='mr-1.5' /> Edit
						</button>

						<button
							onClick={onDelete}
							className='flex items-center px-3 py-1.5 bg-red-500/20 text-red-400 hover:bg-red-500/30 rounded-md text-sm transition-colors'
						>
							<FiTrash2 className='mr-1.5' /> Delete
						</button>
					</div>
				)}
			</div>
		</div>
	);
};

export default ProjectHeader;
