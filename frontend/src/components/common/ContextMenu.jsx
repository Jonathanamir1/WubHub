import React, { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';

const ContextMenu = ({ x, y, onClose, options }) => {
	const menuRef = useRef(null);

	useEffect(() => {
		const handleClickOutside = (event) => {
			if (menuRef.current && !menuRef.current.contains(event.target)) {
				onClose();
			}
		};

		const handleEscape = (event) => {
			if (event.key === 'Escape') {
				onClose();
			}
		};

		document.addEventListener('mousedown', handleClickOutside);
		document.addEventListener('keydown', handleEscape);

		return () => {
			document.removeEventListener('mousedown', handleClickOutside);
			document.removeEventListener('keydown', handleEscape);
		};
	}, [onClose]);

	// Adjust position if near window edges
	const adjustedPosition = () => {
		const padding = 10;
		const menuWidth = 200; // Approximate width of menu
		const menuHeight = options.length * 36; // Approximate height based on items

		let adjustedX = x;
		let adjustedY = y;

		// Check right edge
		if (x + menuWidth + padding > window.innerWidth) {
			adjustedX = window.innerWidth - menuWidth - padding;
		}

		// Check bottom edge
		if (y + menuHeight + padding > window.innerHeight) {
			adjustedY = window.innerHeight - menuHeight - padding;
		}

		return { top: adjustedY, left: adjustedX };
	};

	return createPortal(
		<div
			ref={menuRef}
			className='bg-ableton-dark-200 border border-ableton-dark-100 rounded-md shadow-lg py-1 z-50 fixed'
			style={adjustedPosition()}
		>
			{options.map((option, index) => (
				<div
					key={index}
					className='px-1'
				>
					{option.divider ? (
						<div className='border-t border-ableton-dark-100 my-1'></div>
					) : (
						<button
							disabled={option.disabled}
							className={`w-full text-left px-3 py-2 text-sm rounded-md transition-colors flex items-center ${
								option.danger
									? 'text-red-400 hover:bg-red-900/30'
									: option.disabled
									? 'text-gray-500 cursor-not-allowed'
									: 'text-gray-300 hover:bg-ableton-dark-300'
							}`}
							onClick={() => {
								if (!option.disabled) {
									option.onClick();
									onClose();
								}
							}}
						>
							{option.icon && <span className='mr-2'>{option.icon}</span>}
							{option.label}
						</button>
					)}
				</div>
			))}
		</div>,
		document.body
	);
};

export default ContextMenu;
