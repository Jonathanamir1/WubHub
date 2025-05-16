import React, { useRef } from 'react';
import { useDrag, useDrop } from 'react-dnd';
import { FiFolder, FiLock } from 'react-icons/fi';

const DraggableWorkspaceItem = ({
	workspace,
	index,
	moveWorkspace,
	isPrivate,
	isSelected,
	onContextMenu,
}) => {
	const ref = useRef(null);

	const [{ isDragging }, drag] = useDrag({
		type: 'WORKSPACE',
		item: { id: workspace.id, index },
		collect: (monitor) => ({
			isDragging: monitor.isDragging(),
		}),
	});

	const [, drop] = useDrop({
		accept: 'WORKSPACE',
		hover: (item, monitor) => {
			if (!ref.current) {
				return;
			}
			const dragIndex = item.index;
			const hoverIndex = index;

			// Don't replace items with themselves
			if (dragIndex === hoverIndex) {
				return;
			}

			// Determine rectangle on screen
			const hoverBoundingRect = ref.current.getBoundingClientRect();

			// Get vertical middle
			const hoverMiddleY =
				(hoverBoundingRect.bottom - hoverBoundingRect.top) / 2;

			// Determine mouse position
			const clientOffset = monitor.getClientOffset();

			// Get pixels to the top
			const hoverClientY = clientOffset.y - hoverBoundingRect.top;

			// Only perform the move when the mouse has crossed half of the items height
			// When dragging downward, only move when the cursor is below 50%
			// When dragging upward, only move when the cursor is above 50%

			// Dragging downward
			if (dragIndex < hoverIndex && hoverClientY < hoverMiddleY) {
				return;
			}

			// Dragging upward
			if (dragIndex > hoverIndex && hoverClientY > hoverMiddleY) {
				return;
			}

			// Time to actually perform the action
			moveWorkspace(dragIndex, hoverIndex);

			// Note: we're mutating the monitor item here!
			// Generally it's better to avoid mutations,
			// but it's good here for the sake of performance
			// to avoid expensive index searches.
			item.index = hoverIndex;
		},
	});

	drag(drop(ref));

	return (
		<div
			ref={ref}
			className={`flex items-center justify-between py-2 px-4 rounded-md transition-colors cursor-grab ${
				isDragging ? 'opacity-50' : 'opacity-100'
			} ${
				isSelected
					? 'bg-ableton-dark-200 text-white'
					: 'text-gray-300 hover:bg-ableton-dark-200/50'
			}`}
			onContextMenu={onContextMenu}
			style={{ opacity: isDragging ? 0.5 : 1 }}
		>
			<div className='flex items-center overflow-hidden'>
				<div className='w-4 h-4 mr-3 flex-shrink-0 flex items-center justify-center'>
					{isPrivate ? (
						<FiLock className='w-4 h-4 text-gray-500' />
					) : (
						<FiFolder className='w-4 h-4' />
					)}
				</div>
				<span className='truncate'>{workspace.name}</span>
			</div>
			<span className='text-xs px-1.5 py-0.5 rounded-full border bg-gray-500/20 text-gray-300 border-gray-500/30'>
				{workspace.project_count}
			</span>
		</div>
	);
};

export default DraggableWorkspaceItem;
