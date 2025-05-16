// src/components/layout/Sidebar/Navigation.jsx
import React from 'react';
import { FiChevronLeft, FiChevronRight } from 'react-icons/fi';

const Navigation = ({ navigationStack, navigateBack, getProjectTypeColor }) => {
	if (navigationStack.length === 0) {
		return null;
	}

	return (
		<div className='mb-4 px-4'>
			<button
				onClick={navigateBack}
				className='flex items-center text-gray-400 hover:text-white text-sm py-2 transition-colors'
			>
				<FiChevronLeft className='w-4 h-4 mr-1' /> Back
			</button>

			<div className='flex items-center overflow-x-auto whitespace-nowrap py-2 text-gray-300 text-sm'>
				{navigationStack.map((item, index) => (
					<React.Fragment key={`${item.type}-${item.id}`}>
						{index > 0 && <FiChevronRight className='mx-2 text-gray-500' />}
						<span
							className={
								index === navigationStack.length - 1
									? 'text-white font-medium'
									: 'text-gray-400'
							}
						>
							{item.name}
						</span>
						{index === navigationStack.length - 1 &&
							item.type === 'project' && (
								<span
									className={`ml-2 text-xs px-1.5 py-0.5 rounded-full border ${getProjectTypeColor(
										item.projectType
									)}`}
								>
									{item.projectType}
								</span>
							)}
					</React.Fragment>
				))}
			</div>
		</div>
	);
};

export default Navigation;
