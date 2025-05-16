// frontend/src/components/projects/ContentSection.jsx
import React from 'react';
import { FiPlus, FiDownload, FiTrash2, FiEye } from 'react-icons/fi';
import EmptyState from '../common/EmptyState';

const ContentSection = ({ title, icon, items, emptyMessage, onUpload }) => {
	const formatDate = (dateString) => {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'long',
			day: 'numeric',
		});
	};

	const formatFileSize = (bytes) => {
		if (!bytes) return '';

		const units = ['B', 'KB', 'MB', 'GB'];
		let size = bytes;
		let unitIndex = 0;

		while (size >= 1024 && unitIndex < units.length - 1) {
			size /= 1024;
			unitIndex++;
		}

		return `${size.toFixed(1)} ${units[unitIndex]}`;
	};

	return (
		<div className='bg-ableton-dark-300 rounded-md border border-ableton-dark-200 overflow-hidden'>
			<div className='p-4 border-b border-ableton-dark-200 flex justify-between items-center'>
				<h3 className='text-lg font-medium flex items-center'>
					{icon && <span className='mr-2'>{icon}</span>}
					{title}
				</h3>

				<button
					onClick={onUpload}
					className='flex items-center text-sm px-3 py-1.5 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md transition-colors'
				>
					<FiPlus className='mr-1.5' /> Upload
				</button>
			</div>

			<div className='p-4'>
				{items && items.length > 0 ? (
					<div className='space-y-2'>
						{items.map((item) => (
							<div
								key={item.id}
								className='p-3 bg-ableton-dark-200 rounded-md hover:bg-ableton-dark-100 transition-colors flex justify-between items-center'
							>
								<div className='overflow-hidden'>
									<h4 className='font-medium truncate'>{item.name}</h4>
									<div className='text-sm text-gray-400 flex items-center'>
										<span>Added {formatDate(item.created_at)}</span>
										{item.size && (
											<span className='ml-3'>{formatFileSize(item.size)}</span>
										)}
									</div>
								</div>

								<div className='flex space-x-2'>
									<button
										className='p-1.5 text-gray-400 hover:text-white rounded-md transition-colors'
										title='View'
									>
										<FiEye />
									</button>

									<button
										className='p-1.5 text-gray-400 hover:text-white rounded-md transition-colors'
										title='Download'
									>
										<FiDownload />
									</button>

									<button
										className='p-1.5 text-gray-400 hover:text-red-400 rounded-md transition-colors'
										title='Delete'
									>
										<FiTrash2 />
									</button>
								</div>
							</div>
						))}
					</div>
				) : (
					<EmptyState
						icon={icon}
						title={`No ${title.toLowerCase()} yet`}
						message={emptyMessage}
						actionText='Upload'
						onAction={onUpload}
					/>
				)}
			</div>
		</div>
	);
};

export default ContentSection;
