// src/components/layout/Sidebar/WorkspaceSection.jsx
import React from 'react';
import { Link } from 'react-router-dom';
import { FiChevronRight, FiChevronDown, FiPlus } from 'react-icons/fi';
import DraggableWorkspaceItem from './DraggableWorkspaceItem';
import Spinner from '../../common/Spinner';

const WorkspaceSection = ({
	title,
	sectionKey,
	workspaces,
	loading,
	error,
	collapsedSections,
	toggleSectionCollapse,
	handleCreateWorkspace,
	workspaceId,
	privateWorkspaces,
	moveWorkspace,
	handleWorkspaceContextMenu,
	showCreateButton = false,
}) => {
	if (workspaces.length === 0 && !showCreateButton) {
		return null;
	}

	return (
		<>
			<div
				className='flex justify-between items-center mb-3 px-4 cursor-pointer'
				onClick={() => toggleSectionCollapse(sectionKey)}
			>
				<h3 className='text-gray-400 text-sm font-medium uppercase tracking-wider flex items-center'>
					{collapsedSections[sectionKey] ? (
						<FiChevronRight className='w-3 h-3 mr-1' />
					) : (
						<FiChevronDown className='w-3 h-3 mr-1' />
					)}
					{title}{' '}
					{workspaces.length > 0 && (
						<span className='ml-1'>({workspaces.length})</span>
					)}
				</h3>
				{showCreateButton && (
					<button
						onClick={(e) => {
							e.stopPropagation();
							handleCreateWorkspace();
						}}
						className='text-gray-400 hover:text-ableton-blue-400 transition-colors'
						aria-label='Create new workspace'
					>
						<FiPlus className='w-5 h-5' />
					</button>
				)}
			</div>

			{!collapsedSections[sectionKey] && (
				<div className='space-y-1 mb-5'>
					{loading ? (
						<div className='flex justify-center py-4'>
							<Spinner
								size='sm'
								color='blue'
							/>
						</div>
					) : error ? (
						<div className='text-center py-4 text-red-400 text-sm'>{error}</div>
					) : (
						<>
							{workspaces.length === 0 ? (
								<div className='text-center py-4 text-gray-500 text-sm'>
									No workspaces found
								</div>
							) : (
								workspaces.map((workspace, index) => (
									<Link
										key={workspace.id}
										to={`/workspaces/${workspace.id}`}
									>
										<DraggableWorkspaceItem
											workspace={workspace}
											index={index}
											moveWorkspace={moveWorkspace}
											isPrivate={
												privateWorkspaces &&
												privateWorkspaces.includes(workspace.id)
											}
											isSelected={workspaceId === workspace.id.toString()}
											onContextMenu={(e) =>
												handleWorkspaceContextMenu(e, workspace, index)
											}
										/>
									</Link>
								))
							)}
						</>
					)}
				</div>
			)}
		</>
	);
};

export default WorkspaceSection;
