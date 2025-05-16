// frontend/src/components/projects/VersionsList.jsx
import React from 'react';
import { FiPlus, FiDownload, FiTrash2, FiEye, FiMusic } from 'react-icons/fi';
import EmptyState from '../common/EmptyState';

const VersionsList = ({
	versions,
	selectedVersion,
	setSelectedVersion,
	projectId,
	isOwner,
	currentUserId,
	onCreateVersion,
	onDeleteVersion,
}) => {
	const formatDate = (dateString) => {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'long',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit',
		});
	};

	const handleDeleteClick = (e, versionId) => {
		e.stopPropagation();
		onDeleteVersion(versionId);
	};

	return (
		<div className='bg-ableton-dark-300 rounded-md border border-ableton-dark-200 overflow-hidden'>
			<div className='p-4 border-b border-ableton-dark-200 flex justify-between items-center'>
				<h3 className='text-lg font-medium'>Versions</h3>

				<button
					onClick={onCreateVersion}
					className='flex items-center text-sm px-3 py-1.5 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md transition-colors'
				>
					<FiPlus className='mr-1.5' /> New Version
				</button>
			</div>

			<div className='p-4'>
				{versions && versions.length > 0 ? (
					<div className='space-y-2'>
						{versions.map((version) => (
							<div
								key={version.id}
								className={`p-4 rounded-md transition-colors cursor-pointer ${
									selectedVersion?.id === version.id
										? 'bg-ableton-blue-500/20 border border-ableton-blue-500/30'
										: 'bg-ableton-dark-200 hover:bg-ableton-dark-100 border border-transparent'
								}`}
								onClick={() => setSelectedVersion(version)}
							>
								<div className='flex justify-between items-start'>
									<div>
										<h4 className='font-medium text-lg'>{version.title}</h4>
										<div className='text-sm text-gray-400 mt-1'>
											Created by {version.username} on{' '}
											{formatDate(version.created_at)}
										</div>
									</div>

									<div className='flex space-x-2'>
										<button
											className='p-1.5 text-gray-400 hover:text-white rounded-md transition-colors'
											title='View version details'
											onClick={(e) => {
												e.stopPropagation();
												window.location.href = `/projects/${projectId}/versions/${version.id}`;
											}}
										>
											<FiEye />
										</button>

										{(isOwner || version.user_id === currentUserId) && (
											<button
												className='p-1.5 text-gray-400 hover:text-red-400 rounded-md transition-colors'
												title='Delete version'
												onClick={(e) => handleDeleteClick(e, version.id)}
											>
												<FiTrash2 />
											</button>
										)}
									</div>
								</div>

								{selectedVersion?.id === version.id && (
									<div className='mt-4 pt-4 border-t border-ableton-dark-100'>
										<div className='text-gray-300'>
											Version details and files will be shown here.
										</div>
									</div>
								)}
							</div>
						))}
					</div>
				) : (
					<EmptyState
						icon={<FiMusic className='w-8 h-8' />}
						title='No versions yet'
						message='Create your first version to start tracking your progress'
						actionText='Create Version'
						onAction={onCreateVersion}
					/>
				)}
			</div>
		</div>
	);
};

export default VersionsList;
