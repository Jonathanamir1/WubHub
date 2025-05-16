// src/components/layout/Sidebar/ProjectsList.jsx
import React from 'react';
import { Link } from 'react-router-dom';
import { FiPlus, FiMusic } from 'react-icons/fi';
import Spinner from '../../common/Spinner';

const ProjectsList = ({
	navigationStack,
	workspaceId,
	projectId,
	projects,
	loading,
	sidebarCollapsed,
	handleCreateProject,
	getProjectTypeColor,
}) => {
	// Only show if we're viewing a workspace
	if (
		!(navigationStack.length === 1 && navigationStack[0].type === 'workspace')
	) {
		return null;
	}

	return (
		<>
			{!sidebarCollapsed && (
				<div className='flex justify-between items-center mb-3 px-4'>
					<h3 className='text-gray-400 text-sm font-medium uppercase tracking-wider'>
						Projects
					</h3>
					<button
						onClick={handleCreateProject}
						className='text-gray-400 hover:text-ableton-blue-400 transition-colors'
						aria-label='Create new project'
					>
						<FiPlus className='w-5 h-5' />
					</button>
				</div>
			)}

			<div className='space-y-1'>
				{loading ? (
					<div className='flex justify-center py-4'>
						<Spinner
							size='sm'
							color='blue'
						/>
					</div>
				) : (
					<>
						{projects.length === 0 ? (
							<div className='text-center py-4 text-gray-500 text-sm'>
								No projects found
							</div>
						) : (
							projects.map((project) => (
								<Link
									key={project.id}
									to={`/workspaces/${workspaceId}/projects/${project.id}`}
									className={`flex items-center justify-between py-2 px-4 rounded-md transition-colors ${
										projectId === project.id.toString()
											? 'bg-ableton-dark-200 text-white'
											: 'text-gray-300 hover:bg-ableton-dark-200/50'
									}`}
								>
									<div className='flex items-center overflow-hidden'>
										<FiMusic className='w-4 h-4 mr-3 flex-shrink-0' />
										<span className={sidebarCollapsed ? 'hidden' : 'truncate'}>
											{project.title}
										</span>
									</div>
									{!sidebarCollapsed && (
										<span
											className={`text-xs px-1.5 py-0.5 rounded-full border ${getProjectTypeColor(
												project.project_type
											)}`}
										>
											{project.project_type}
										</span>
									)}
								</Link>
							))
						)}
					</>
				)}
			</div>
		</>
	);
};

export default ProjectsList;
