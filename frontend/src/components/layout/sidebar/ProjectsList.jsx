// frontend/src/components/layout/sidebar/ProjectsList.jsx
import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { FiPlus, FiMusic } from 'react-icons/fi';
import Spinner from '../../common/Spinner';
import api from '../../../services/api';

const ProjectsList = ({
	navigationStack,
	workspaceId,
	projectId,
	sidebarCollapsed,
	handleCreateProject,
	getProjectTypeColor,
}) => {
	const [projects, setProjects] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);

	// Fetch projects when workspaceId changes
	useEffect(() => {
		if (
			workspaceId &&
			navigationStack.length === 1 &&
			navigationStack[0].type === 'workspace'
		) {
			fetchProjects(workspaceId);
		}
	}, [workspaceId, navigationStack]);

	const fetchProjects = async (wsId) => {
		try {
			setLoading(true);
			const response = await api.getProjects(wsId);
			setProjects(response.data || []);
			setError(null);
		} catch (err) {
			console.error('Error fetching projects:', err);
			setError('Failed to load projects');

			// Fallback to mock data during development
			const mockProjects = [
				{
					id: 1,
					title: 'Summer EP',
					description: 'Four-track summer vibes EP',
					project_type: 'production',
					version_count: 12,
					updated_at: '2023-05-12T10:15:00Z',
				},
				{
					id: 2,
					title: 'Client Mix - Jane Doe',
					description: "Mixing project for Jane's album",
					project_type: 'mixing',
					version_count: 8,
					updated_at: '2023-05-10T16:45:00Z',
				},
			];
			setProjects(mockProjects);
		} finally {
			setLoading(false);
		}
	};

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
				) : error ? (
					<div className='text-center py-4 text-red-500 text-sm'>{error}</div>
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
									{!sidebarCollapsed && project.project_type && (
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
