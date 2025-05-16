// frontend/src/components/projects/CollaboratorsList.jsx
import React from 'react';
import { FiPlus, FiTrash2, FiEdit, FiUsers } from 'react-icons/fi';
import EmptyState from '../common/EmptyState';

const CollaboratorsList = ({ collaborators, isOwner, onInvite }) => {
	const getRoleBadgeClass = (role) => {
		switch (role) {
			case 'owner':
				return 'bg-ableton-blue-500/20 text-ableton-blue-300 border border-ableton-blue-500/30';
			case 'collaborator':
				return 'bg-green-500/20 text-green-300 border border-green-500/30';
			case 'viewer':
				return 'bg-gray-500/20 text-gray-300 border border-gray-500/30';
			default:
				return 'bg-gray-500/20 text-gray-300 border border-gray-500/30';
		}
	};

	return (
		<div className='bg-ableton-dark-300 rounded-md border border-ableton-dark-200 overflow-hidden'>
			<div className='p-4 border-b border-ableton-dark-200 flex justify-between items-center'>
				<h3 className='text-lg font-medium'>Collaborators</h3>

				{isOwner && (
					<button
						onClick={onInvite}
						className='flex items-center text-sm px-3 py-1.5 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md transition-colors'
					>
						<FiPlus className='mr-1.5' /> Invite
					</button>
				)}
			</div>

			<div className='p-4'>
				{collaborators && collaborators.length > 0 ? (
					<div className='space-y-3'>
						{collaborators.map((collaborator) => (
							<div
								key={collaborator.id}
								className='p-4 bg-ableton-dark-200 rounded-md flex justify-between items-center'
							>
								<div className='flex items-center'>
									<div className='w-10 h-10 rounded-full bg-ableton-blue-500 flex items-center justify-center text-white font-medium mr-3'>
										{collaborator.username?.charAt(0)?.toUpperCase() || 'U'}
									</div>

									<div>
										<h4 className='font-medium'>
											{collaborator.name || collaborator.username}
										</h4>
										<div className='flex items-center mt-1'>
											<span
												className={`px-2 py-0.5 rounded-full text-xs ${getRoleBadgeClass(
													collaborator.role
												)}`}
											>
												{collaborator.role}
											</span>
										</div>
									</div>
								</div>

								{isOwner && collaborator.role !== 'owner' && (
									<div className='flex space-x-2'>
										<button
											className='p-1.5 text-gray-400 hover:text-white rounded-md transition-colors'
											title='Edit role'
										>
											<FiEdit />
										</button>

										<button
											className='p-1.5 text-gray-400 hover:text-red-400 rounded-md transition-colors'
											title='Remove collaborator'
										>
											<FiTrash2 />
										</button>
									</div>
								)}
							</div>
						))}
					</div>
				) : (
					<EmptyState
						icon={<FiUsers className='w-8 h-8' />}
						title='No collaborators yet'
						message='Invite others to collaborate on this project'
						actionText='Invite Collaborators'
						onAction={onInvite}
						showAction={isOwner}
					/>
				)}
			</div>
		</div>
	);
};

export default CollaboratorsList;
