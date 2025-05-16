// src/components/layout/Sidebar/WorkspacesList.jsx
import React from 'react';
import { Link } from 'react-router-dom';
import { FiFolder, FiLock, FiPlus } from 'react-icons/fi';
import WorkspaceSection from './WorkspaceSection';

const WorkspacesList = ({
	navigationStack,
	workspaces,
	loading,
	error,
	sidebarCollapsed,
	collapsedSections,
	toggleSectionCollapse,
	handleCreateWorkspace,
	workspaceId,
	privateWorkspaces,
	moveWorkspace,
	handleWorkspaceContextMenu,
	getFavoriteWorkspaces,
	getRegularWorkspaces,
	getPrivateWorkspaces,
}) => {
	// Only show if we're at dashboard level
	if (navigationStack.length !== 0) {
		return null;
	}

	// For expanded sidebar view
	if (!sidebarCollapsed) {
		return (
			<>
				{/* Favorite workspaces section */}
				{getFavoriteWorkspaces().length > 0 && (
					<WorkspaceSection
						title='Favorites'
						sectionKey='favorites'
						workspaces={getFavoriteWorkspaces()}
						loading={loading}
						error={error}
						collapsedSections={collapsedSections}
						toggleSectionCollapse={toggleSectionCollapse}
						workspaceId={workspaceId}
						privateWorkspaces={privateWorkspaces}
						moveWorkspace={moveWorkspace}
						handleWorkspaceContextMenu={handleWorkspaceContextMenu}
					/>
				)}

				{/* Regular workspaces section */}
				<WorkspaceSection
					title='Workspaces'
					sectionKey='workspaces'
					workspaces={getRegularWorkspaces()}
					loading={loading}
					error={error}
					collapsedSections={collapsedSections}
					toggleSectionCollapse={toggleSectionCollapse}
					handleCreateWorkspace={handleCreateWorkspace}
					workspaceId={workspaceId}
					privateWorkspaces={privateWorkspaces}
					moveWorkspace={moveWorkspace}
					handleWorkspaceContextMenu={handleWorkspaceContextMenu}
					showCreateButton={true}
				/>

				{/* Private workspaces section */}
				{getPrivateWorkspaces().length > 0 && (
					<WorkspaceSection
						title='Private'
						sectionKey='private'
						workspaces={getPrivateWorkspaces()}
						loading={loading}
						error={error}
						collapsedSections={collapsedSections}
						toggleSectionCollapse={toggleSectionCollapse}
						workspaceId={workspaceId}
						privateWorkspaces={privateWorkspaces}
						moveWorkspace={moveWorkspace}
						handleWorkspaceContextMenu={handleWorkspaceContextMenu}
					/>
				)}
			</>
		);
	}

	// For collapsed sidebar - simplified view with just icons
	return (
		<div className='flex flex-col items-center space-y-4 mt-4'>
			{workspaces.map((workspace) => (
				<Link
					key={workspace.id}
					to={`/workspaces/${workspace.id}`}
					className={`flex items-center justify-center w-10 h-10 rounded-md transition-colors ${
						workspaceId === workspace.id.toString()
							? 'bg-ableton-dark-200 text-white'
							: 'text-gray-300 hover:bg-ableton-dark-200/50'
					}`}
					title={workspace.name}
				>
					{privateWorkspaces.includes(workspace.id) ? (
						<FiLock className='w-5 h-5' />
					) : (
						<FiFolder className='w-5 h-5' />
					)}
				</Link>
			))}
			<button
				onClick={handleCreateWorkspace}
				className='flex items-center justify-center w-10 h-10 rounded-md text-gray-400 hover:bg-ableton-dark-200/50 hover:text-white transition-colors'
				title='Create new workspace'
			>
				<FiPlus className='w-5 h-5' />
			</button>
		</div>
	);
};

export default WorkspacesList;
