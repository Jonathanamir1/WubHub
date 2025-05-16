// frontend/src/components/common/EmptyState.jsx
import React from 'react';
import { FiPlus } from 'react-icons/fi';

const EmptyState = ({
	icon,
	title,
	message,
	actionText,
	onAction,
	showAction = true,
}) => {
	return (
		<div className='flex flex-col items-center justify-center py-12 px-4 text-center'>
			{icon && <div className='text-gray-500 mb-3'>{icon}</div>}

			<h4 className='text-lg font-medium mb-1'>{title}</h4>

			<p className='text-gray-400 mb-4 max-w-sm'>{message}</p>

			{showAction && onAction && (
				<button
					onClick={onAction}
					className='flex items-center px-4 py-2 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md transition-colors'
				>
					<FiPlus className='mr-1.5' /> {actionText || 'Add'}
				</button>
			)}
		</div>
	);
};

export default EmptyState;
