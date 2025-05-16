// Updated Sidebar.jsx
import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useParams, useLocation } from 'react-router-dom';
import {
	FiPlus,
	FiFolder,
	FiMusic,
	FiHome,
	FiSettings,
	FiChevronLeft,
	FiChevronRight,
} from 'react-icons/fi';
import api from '../../services/api';
import { useAuth } from '../../contexts/AuthContext';
import Spinner from '../common/Spinner';
import CreateWorkspaceModal from '../workspaces/CreateWorkspaceModal';

const Sidebar = () => {
	const { currentUser } = useAuth();
	const [workspaces, setWorkspaces] = useState([]);
	const [projects, setProjects] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const navigate = useNavigate();
	const { workspaceId, projectId } = useParams();
	const location = useLocation();
	const [currentWorkspace, setCurrentWorkspace] = useState(null);
	const [navigationStack, setNavigationStack] = useState([]);
	const [showCreateWorkspaceModal, setShowCreateWorkspaceModal] =
		useState(false);

	useEffect(() => {
		fetchWorkspaces();
	}, []);

	const fetchWorkspaces = async () => {
		try {
			setLoading(true);
			const response = await api.getWorkspaces();
			setWorkspaces(response.data || []);
			setError(null);
		} catch (err) {
			console.error('Error fetching workspaces for sidebar:', err);
			setError('Failed to load workspaces');
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		// Update navigation stack based on URL
		if (workspaceId) {
			const workspace = workspaces.find((w) => w.id.toString() === workspaceId);
			if (workspace) {
				setCurrentWorkspace(workspace);

				// If we're at workspace level
				if (!projectId) {
					setNavigationStack([
						{
							type: 'workspace',
							id: workspace.id,
							name: workspace.name,
						},
					]);

					// Fetch projects for this workspace
					fetchProjects(workspaceId);
				}
				// If we're at project level
				else {
					// We'll handle this in another useEffect
				}
			}
		} else {
			// Reset if we're at dashboard
			setNavigationStack([]);
			setCurrentWorkspace(null);
			setProjects([]);
		}
	}, [workspaceId, workspaces]);

	useEffect(() => {
		// Handle project level navigation
		if (workspaceId && projectId) {
			const workspace = workspaces.find((w) => w.id.toString() === workspaceId);

			// Fetch projects if not already loaded
			if (projects.length === 0) {
				fetchProjects(workspaceId);
			}

			const project = projects.find((p) => p.id.toString() === projectId);

			if (workspace && project) {
				setNavigationStack([
					{
						type: 'workspace',
						id: workspace.id,
						name: workspace.name,
					},
					{
						type: 'project',
						id: project.id,
						name: project.title,
						projectType: project.project_type,
					},
				]);
			}
		}
	}, [workspaceId, projectId, workspaces, projects]);

	const fetchProjects = async (wsId) => {
		try {
			const response = await api.getProjects(wsId);
			setProjects(response.data || []);
		} catch (err) {
			console.error('Error fetching projects:', err);
		}
	};

	// Get project type color for badges
	const getProjectTypeColor = (type) => {
		switch (type) {
			case 'production':
				return 'bg-ableton-blue-500/20 text-ableton-blue-300 border-ableton-blue-500/30';
			case 'songwriting':
				return 'bg-ableton-purple-500/20 text-ableton-purple-300 border-ableton-purple-500/30';
			case 'mixing':
				return 'bg-green-500/20 text-green-300 border-green-500/30';
			case 'mastering':
				return 'bg-yellow-500/20 text-yellow-300 border-yellow-500/30';
			default:
				return 'bg-gray-500/20 text-gray-300 border-gray-500/30';
		}
	};

	const handleCreateWorkspace = () => {
		setShowCreateWorkspaceModal(true);
	};

	const handleWorkspaceCreated = (newWorkspace) => {
		setWorkspaces([...workspaces, newWorkspace]);
	};

	const handleCreateProject = () => {
		navigate(`/workspaces/${workspaceId}`, {
			state: { openCreateProjectModal: true },
		});
	};

	const navigateBack = () => {
		if (navigationStack.length > 1) {
			// Go back one level
			const previousLevel = navigationStack[navigationStack.length - 2];
			if (previousLevel.type === 'workspace') {
				navigate(`/workspaces/${previousLevel.id}`);
			} else {
				navigate('/dashboard');
			}
		} else if (navigationStack.length === 1) {
			// Go back to dashboard
			navigate('/dashboard');
		}
	};

	// Render breadcrumb navigation
	const renderNavigation = () => {
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

	return (
		<>
			<div className='h-screen bg-ableton-dark-300 w-64 fixed left-0 top-0 pt-16 border-r border-ableton-dark-200 overflow-y-auto'>
				<div className='p-4'>
					<div className='mb-4'>
						<Link
							to='/dashboard'
							className={`flex items-center py-2 px-4 rounded-md transition-colors ${
								location.pathname === '/dashboard'
									? 'bg-ableton-dark-200 text-white'
									: 'text-gray-300 hover:bg-ableton-dark-200/50'
							}`}
						>
							<FiHome className='w-5 h-5 mr-3' />
							<span>Dashboard</span>
						</Link>
					</div>

					{/* Breadcrumb navigation */}
					{renderNavigation()}

					{/* Show appropriate content based on navigation level */}
					{navigationStack.length === 0 && (
						<>
							<div className='flex justify-between items-center mb-3 px-4'>
								<h3 className='text-gray-400 text-sm font-medium uppercase tracking-wider'>
									Workspaces
								</h3>
								<button
									onClick={handleCreateWorkspace}
									className='text-gray-400 hover:text-ableton-blue-400 transition-colors'
									aria-label='Create new workspace'
								>
									<FiPlus className='w-5 h-5' />
								</button>
							</div>

							<div className='space-y-1'>
								{loading ? (
									<div className='flex justify-center py-4'>
										<Spinner
											size='sm'
											color='blue'
										/>
									</div>
								) : error ? (
									<div className='text-center py-4 text-red-400 text-sm'>
										{error}
									</div>
								) : (
									<>
										{workspaces.length === 0 ? (
											<div className='text-center py-4 text-gray-500 text-sm'>
												No workspaces found
											</div>
										) : (
											workspaces.map((workspace) => (
												<Link
													key={workspace.id}
													to={`/workspaces/${workspace.id}`}
													className={`flex items-center justify-between py-2 px-4 rounded-md transition-colors ${
														workspaceId === workspace.id.toString()
															? 'bg-ableton-dark-200 text-white'
															: 'text-gray-300 hover:bg-ableton-dark-200/50'
													}`}
												>
													<div className='flex items-center overflow-hidden'>
														<FiFolder className='w-4 h-4 mr-3 flex-shrink-0' />
														<span className='truncate'>{workspace.name}</span>
													</div>
													<span className='text-xs px-1.5 py-0.5 rounded-full border bg-gray-500/20 text-gray-300 border-gray-500/30'>
														{workspace.project_count}
													</span>
												</Link>
											))
										)}
									</>
								)}
							</div>
						</>
					)}

					{/* If we're viewing a workspace, show its projects */}
					{navigationStack.length === 1 &&
						navigationStack[0].type === 'workspace' && (
							<>
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
															<span className='truncate'>{project.title}</span>
														</div>
														<span
															className={`text-xs px-1.5 py-0.5 rounded-full border ${getProjectTypeColor(
																project.project_type
															)}`}
														>
															{project.project_type}
														</span>
													</Link>
												))
											)}
										</>
									)}
								</div>
							</>
						)}

					{/* If we're viewing a project, show project-specific navigation */}
					{navigationStack.length === 2 &&
						navigationStack[1].type === 'project' && (
							<>
								<div className='mb-3 px-4'>
									<h3 className='text-gray-400 text-sm font-medium uppercase tracking-wider'>
										Project Navigation
									</h3>
								</div>

								<div className='space-y-1'>
									<Link
										to={`/workspaces/${workspaceId}/projects/${projectId}/overview`}
										className={`flex items-center py-2 px-4 rounded-md transition-colors ${
											location.pathname.includes('/overview')
												? 'bg-ableton-dark-200 text-white'
												: 'text-gray-300 hover:bg-ableton-dark-200/50'
										}`}
									>
										<span>Overview</span>
									</Link>
									<Link
										to={`/workspaces/${workspaceId}/projects/${projectId}/versions`}
										className={`flex items-center py-2 px-4 rounded-md transition-colors ${
											location.pathname.includes('/versions')
												? 'bg-ableton-dark-200 text-white'
												: 'text-gray-300 hover:bg-ableton-dark-200/50'
										}`}
									>
										<span>Versions</span>
									</Link>
									<Link
										to={`/workspaces/${workspaceId}/projects/${projectId}/collaborators`}
										className={`flex items-center py-2 px-4 rounded-md transition-colors ${
											location.pathname.includes('/collaborators')
												? 'bg-ableton-dark-200 text-white'
												: 'text-gray-300 hover:bg-ableton-dark-200/50'
										}`}
									>
										<span>Collaborators</span>
									</Link>
									<Link
										to={`/workspaces/${workspaceId}/projects/${projectId}/settings`}
										className={`flex items-center py-2 px-4 rounded-md transition-colors ${
											location.pathname.includes('/settings')
												? 'bg-ableton-dark-200 text-white'
												: 'text-gray-300 hover:bg-ableton-dark-200/50'
										}`}
									>
										<span>Settings</span>
									</Link>
								</div>
							</>
						)}

					<div className='mt-8 pt-4 border-t border-ableton-dark-200'>
						<div className='flex justify-between items-center mb-3 px-4'>
							<h3 className='text-gray-400 text-sm font-medium uppercase tracking-wider'>
								Tools
							</h3>
						</div>

						<Link
							to='/dashboard?tab=recent'
							className={`flex items-center py-2 px-4 rounded-md transition-colors ${
								location.pathname === '/dashboard' &&
								location.search.includes('tab=recent')
									? 'bg-ableton-dark-200 text-white'
									: 'text-gray-300 hover:bg-ableton-dark-200/50'
							}`}
						>
							<FiMusic className='w-4 h-4 mr-3' />
							<span>Recent Projects</span>
						</Link>

						<Link
							to='/settings'
							className={`flex items-center py-2 px-4 rounded-md transition-colors ${
								location.pathname === '/settings'
									? 'bg-ableton-dark-200 text-white'
									: 'text-gray-300 hover:bg-ableton-dark-200/50'
							}`}
						>
							<FiSettings className='w-4 h-4 mr-3' />
							<span>Settings</span>
						</Link>
					</div>

					{/* User info at bottom */}
					<div className='absolute bottom-0 left-0 right-0 p-4 border-t border-ableton-dark-200 bg-ableton-dark-300'>
						<div className='flex items-center'>
							<div className='w-8 h-8 rounded-full bg-ableton-blue-500 flex items-center justify-center text-white font-medium mr-3'>
								{currentUser?.username?.charAt(0)?.toUpperCase() || 'U'}
							</div>
							<div className='overflow-hidden'>
								<div className='font-medium text-white truncate'>
									{currentUser?.username || 'User'}
								</div>
								<div className='text-xs text-gray-400 truncate'>
									{currentUser?.email || ''}
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>

			{/* Create Workspace Modal */}
			<CreateWorkspaceModal
				isOpen={showCreateWorkspaceModal}
				onClose={() => setShowCreateWorkspaceModal(false)}
				onWorkspaceCreated={handleWorkspaceCreated}
			/>
		</>
	);
};

export default Sidebar;
