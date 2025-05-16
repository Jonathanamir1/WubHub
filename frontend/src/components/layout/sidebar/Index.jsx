import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useParams, useLocation } from 'react-router-dom';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import {
	FiHome,
	FiSettings,
	FiChevronLeft,
	FiChevronRight,
	FiEdit2,
	FiTrash2,
	FiChevronsUp,
	FiChevronsDown,
	FiEye,
	FiEyeOff,
	FiFolder,
	FiStar,
} from 'react-icons/fi';
import { useSidebar, SidebarProvider } from './SidebarContext';
import WorkspacesList from './WorkspacesList';
import ProjectsList from './ProjectsList';
import Navigation from './Navigation';
import RenameWorkspaceModal from './RenameWorkspaceModal';
import CreateWorkspaceModal from '../../workspaces/CreateWorkspaceModal';
import ContextMenu from '../../common/ContextMenu';
import api from '../../../services/api';

// Inner component that uses the sidebar context
const SidebarContent = () => {
	const {
		workspaces,
		loading,
		error,
		sidebarCollapsed,
		setSidebarCollapsed,
		privateWorkspaces,
		collapsedSections,
		toggleSectionCollapse,
		moveWorkspace,
		toggleFavoriteWorkspace,
		togglePrivateWorkspace,
		handleDeleteWorkspace,
		addWorkspace,
		updateWorkspace,
		getFavoriteWorkspaces,
		getPrivateWorkspaces,
		getRegularWorkspaces,
	} = useSidebar();

	const navigate = useNavigate();
	const { workspaceId, projectId } = useParams();
	const location = useLocation();
	const [currentWorkspace, setCurrentWorkspace] = useState(null);
	const [navigationStack, setNavigationStack] = useState([]);
	const [projects, setProjects] = useState([]);
	const [showCreateWorkspaceModal, setShowCreateWorkspaceModal] =
		useState(false);
	const [contextMenu, setContextMenu] = useState(null);
	const [renameWorkspaceModal, setRenameWorkspaceModal] = useState({
		isOpen: false,
		workspace: null,
	});

	// Update navigation when URL changes
	useEffect(() => {
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
			}
		} else {
			// Reset if we're at dashboard
			setNavigationStack([]);
			setCurrentWorkspace(null);
			setProjects([]);
		}
	}, [workspaceId, workspaces]);

	// Handle project level navigation
	useEffect(() => {
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
		addWorkspace(newWorkspace);
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

	// Handle workspace context menu
	const handleWorkspaceContextMenu = (e, workspace, index) => {
		e.preventDefault();

		const isPrivate = privateWorkspaces.includes(workspace.id);
		const isFavorite = getFavoriteWorkspaces().some(
			(ws) => ws.id === workspace.id
		);

		setContextMenu({
			x: e.clientX,
			y: e.clientY,
			options: [
				{
					label: 'Open workspace',
					icon: <FiFolder />,
					onClick: () => {
						navigate(`/workspaces/${workspace.id}`);
					},
				},
				{
					label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
					icon: <FiStar />,
					onClick: () => {
						toggleFavoriteWorkspace(workspace.id);
					},
				},
				{
					label: 'Rename',
					icon: <FiEdit2 />,
					onClick: () => {
						setRenameWorkspaceModal({
							isOpen: true,
							workspace: workspace,
						});
					},
				},
				{
					label: isPrivate ? 'Make public' : 'Make private',
					icon: isPrivate ? <FiEye /> : <FiEyeOff />,
					onClick: () => {
						togglePrivateWorkspace(workspace.id);
					},
				},
				{
					divider: true,
				},
				{
					label: 'Move up',
					icon: <FiChevronsUp />,
					disabled: index === 0,
					onClick: () => {
						if (index > 0) {
							moveWorkspace(index, index - 1);
						}
					},
				},
				{
					label: 'Move down',
					icon: <FiChevronsDown />,
					disabled: index === getRegularWorkspaces().length - 1,
					onClick: () => {
						if (index < workspaces.length - 1) {
							moveWorkspace(index, index + 1);
						}
					},
				},
				{
					divider: true,
				},
				{
					label: 'Delete workspace',
					icon: <FiTrash2 />,
					danger: true,
					onClick: () => {
						if (
							window.confirm(
								`Are you sure you want to delete ${workspace.name}?`
							)
						) {
							const success = handleDeleteWorkspace(workspace.id);

							// Navigate to dashboard if current workspace is deleted
							if (
								success &&
								currentWorkspace &&
								currentWorkspace.id === workspace.id
							) {
								navigate('/dashboard');
							}
						}
					},
				},
			],
		});
	};

	// Handle workspace rename
	const handleWorkspaceRenamed = (updatedWorkspace) => {
		updateWorkspace(updatedWorkspace);

		// If the renamed workspace is the current one, update navigation
		if (currentWorkspace && currentWorkspace.id === updatedWorkspace.id) {
			setCurrentWorkspace(updatedWorkspace);

			// Update navigation stack if needed
			if (
				navigationStack.length > 0 &&
				navigationStack[0].id === updatedWorkspace.id
			) {
				const newStack = [...navigationStack];
				newStack[0] = {
					...newStack[0],
					name: updatedWorkspace.name,
				};
				setNavigationStack(newStack);
			}
		}
	};

	return (
		<>
			<DndProvider backend={HTML5Backend}>
				<div
					className={`h-screen ${
						sidebarCollapsed ? 'w-16' : 'w-64'
					} fixed left-0 top-0 pt-16 border-r border-ableton-dark-200 overflow-y-auto bg-ableton-dark-300 transition-all duration-300`}
				>
					{/* Toggle sidebar button */}
					<button
						onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
						className='absolute right-0 top-6 bg-ableton-dark-200 p-1 rounded-l-md text-gray-400 hover:text-white'
					>
						{sidebarCollapsed ? <FiChevronRight /> : <FiChevronLeft />}
					</button>

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
								<span className={`${sidebarCollapsed ? 'hidden' : 'inline'}`}>
									Dashboard
								</span>
							</Link>
						</div>

						{/* Breadcrumb navigation */}
						{!sidebarCollapsed && (
							<Navigation
								navigationStack={navigationStack}
								navigateBack={navigateBack}
								getProjectTypeColor={getProjectTypeColor}
							/>
						)}

						{/* Workspaces List */}
						<WorkspacesList
							navigationStack={navigationStack}
							workspaces={workspaces}
							loading={loading}
							error={error}
							sidebarCollapsed={sidebarCollapsed}
							collapsedSections={collapsedSections}
							toggleSectionCollapse={toggleSectionCollapse}
							handleCreateWorkspace={handleCreateWorkspace}
							workspaceId={workspaceId}
							privateWorkspaces={privateWorkspaces}
							moveWorkspace={moveWorkspace}
							handleWorkspaceContextMenu={handleWorkspaceContextMenu}
							getFavoriteWorkspaces={getFavoriteWorkspaces}
							getRegularWorkspaces={getRegularWorkspaces}
							getPrivateWorkspaces={getPrivateWorkspaces}
						/>

						{/* Projects List */}
						<ProjectsList
							navigationStack={navigationStack}
							workspaceId={workspaceId}
							projectId={projectId}
							projects={projects}
							loading={loading}
							sidebarCollapsed={sidebarCollapsed}
							handleCreateProject={handleCreateProject}
							getProjectTypeColor={getProjectTypeColor}
						/>

						{/* Settings link at bottom */}
						<div className='absolute bottom-0 left-0 w-full p-4 border-t border-ableton-dark-200'>
							<Link
								to='/settings'
								className={`flex items-center py-2 px-4 rounded-md transition-colors ${
									location.pathname === '/settings'
										? 'bg-ableton-dark-200 text-white'
										: 'text-gray-300 hover:bg-ableton-dark-200/50'
								}`}
							>
								<FiSettings className='w-5 h-5 mr-3' />
								{!sidebarCollapsed && <span>Settings</span>}
							</Link>
						</div>
					</div>
				</div>

				{/* Context menu */}
				{contextMenu && (
					<ContextMenu
						x={contextMenu.x}
						y={contextMenu.y}
						options={contextMenu.options}
						onClose={() => setContextMenu(null)}
					/>
				)}
			</DndProvider>

			{/* Modal for creating new workspace */}
			{showCreateWorkspaceModal && (
				<CreateWorkspaceModal
					onClose={() => setShowCreateWorkspaceModal(false)}
					onWorkspaceCreated={handleWorkspaceCreated}
				/>
			)}

			{/* Modal for renaming workspace */}
			{renameWorkspaceModal.isOpen && renameWorkspaceModal.workspace && (
				<RenameWorkspaceModal
					workspace={renameWorkspaceModal.workspace}
					onClose={() =>
						setRenameWorkspaceModal({ isOpen: false, workspace: null })
					}
					onWorkspaceRenamed={handleWorkspaceRenamed}
				/>
			)}
		</>
	);
};

// Wrapper component that provides context
const Sidebar = () => {
	return (
		<SidebarProvider>
			<SidebarContent />
		</SidebarProvider>
	);
};

export default Sidebar;
