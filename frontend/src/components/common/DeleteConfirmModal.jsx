// frontend/src/components/common/DeleteConfirmModal.jsx
import React from 'react';
import { FiX, FiAlertTriangle } from 'react-icons/fi';

const DeleteConfirmModal = ({
	show,
	onClose,
	onConfirm,
	title,
	message,
	confirmText,
}) => {
	if (!show) return null;

	return (
		<div className='fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50'>
			<div className='bg-ableton-dark-300 rounded-md shadow-xl w-full max-w-md'>
				<div className='flex justify-between items-center p-4 border-b border-ableton-dark-200'>
					<h2 className='text-xl font-medium flex items-center text-red-400'>
						<FiAlertTriangle className='mr-2' /> {title || 'Confirm Deletion'}
					</h2>

					<button
						onClick={onClose}
						className='text-gray-400 hover:text-white transition-colors'
					>
						<FiX className='w-5 h-5' />
					</button>
				</div>

				<div className='p-4'>
					<p className='text-gray-300 mb-6'>
						{message ||
							'Are you sure you want to delete this item? This action cannot be undone.'}
					</p>

					<div className='flex space-x-3'>
						<button
							onClick={onClose}
							className='flex-1 py-3 bg-ableton-dark-200 hover:bg-ableton-dark-100 text-white rounded-md transition-colors'
						>
							Cancel
						</button>

						<button
							onClick={onConfirm}
							className='flex-1 py-3 bg-red-500 hover:bg-red-600 text-white rounded-md transition-colors'
						>
							{confirmText || 'Delete'}
						</button>
					</div>
				</div>
			</div>
		</div>
	);
};

export default DeleteConfirmModal;
