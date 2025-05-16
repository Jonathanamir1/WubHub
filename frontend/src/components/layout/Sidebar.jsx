// Handle workspace rename
const handleWorkspaceRenamed = (updatedWorkspace) => {
	// Update workspaces state with the renamed workspace
	setWorkspaces(
		workspaces.map((ws) =>
			ws.id === updatedWorkspace.id ? updatedWorkspace : ws
		)
	);

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
// frontend/src/components/layout/Sidebar.jsx
import React, { useState, useEffect, useRef } from 'react';
import { Link, useNavigate, useParams, useLocation } from 'react-router-dom';
import {
	FiPlus,
	FiFolder,
	FiMusic,
	FiHome,
	FiSettings,
	FiChevronLeft,
	FiChevronRight,
	FiMoreVertical,
	FiLock,
	FiEdit2,
	FiTrash2,
	FiChevronsUp,
	FiChevronsDown,
	FiEye,
	FiEyeOff,
	FiHeart,
	FiStar,
} from 'react-icons/fi';
import { DndProvider, useDrag, useDrop } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import api from '../../services/api';
import { useAuth } from '../../contexts/AuthContext';
import Spinner from '../common/Spinner';
import CreateWorkspaceModal from '../workspaces/CreateWorkspaceModal';
import RenameWorkspaceModal from '../workspaces/RenameWorkspaceModal';
import ContextMenu from '../common/ContextMenu';

// Context menu component for right-click options has been moved to its own file

// Draggable workspace item component
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

const Sidebar = () => {
	const { currentUser } = useAuth();
	const [workspaces, setWorkspaces] = useState([]);
	const [userWorkspaceOrder, setUserWorkspaceOrder] = useState([]);
	const [favoriteWorkspaces, setFavoriteWorkspaces] = useState([]);
	const [privateWorkspaces, setPrivateWorkspaces] = useState([]);
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
	const [contextMenu, setContextMenu] = useState(null);
	const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
	const [collapsedSections, setCollapsedSections] = useState({
		favorites: false,
		workspaces: false,
		private: false,
	});
	const [renameWorkspaceModal, setRenameWorkspaceModal] = useState({
		isOpen: false,
		workspace: null,
	});

	// Fetch workspaces
	useEffect(() => {
		fetchWorkspaces();
		fetchWorkspacePreferences();
	}, []);

	const fetchWorkspaces = async () => {
		try {
			setLoading(true);
			const response = await api.getWorkspaces();
			const workspaceData = response.data || [];

			setWorkspaces(workspaceData);
			setError(null);
		} catch (err) {
			console.error('Error fetching workspaces for sidebar:', err);
			setError('Failed to load workspaces');
		} finally {
			setLoading(false);
		}
	};

	// Fetch user preferences from backend
	const fetchWorkspacePreferences = async () => {
		try {
			const response = await api.getWorkspacePreferences();
			const {
				workspace_order,
				favorite_workspaces,
				private_workspaces,
				collapsed_sections,
			} = response.data;

			if (workspace_order && workspace_order.length > 0) {
				setUserWorkspaceOrder(workspace_order);
			}

			if (favorite_workspaces) {
				setFavoriteWorkspaces(favorite_workspaces);
			}

			if (private_workspaces) {
				setPrivateWorkspaces(private_workspaces);
			}

			if (collapsed_sections) {
				setCollapsedSections(collapsed_sections);
			}
		} catch (err) {
			console.error('Error fetching workspace preferences:', err);
			// Fall back to localStorage if API fails
			fallbackToLocalStorage();
		}
	};

	// Fallback to localStorage if API fails
	const fallbackToLocalStorage = () => {
		const savedOrder = localStorage.getItem('workspaceOrder');
		if (savedOrder) {
			setUserWorkspaceOrder(JSON.parse(savedOrder));
		}

		const savedFavorites = localStorage.getItem('favoriteWorkspaces');
		if (savedFavorites) {
			setFavoriteWorkspaces(JSON.parse(savedFavorites));
		}

		const savedPrivate = localStorage.getItem('privateWorkspaces');
		if (savedPrivate) {
			setPrivateWorkspaces(JSON.parse(savedPrivate));
		}

		const savedCollapsed = localStorage.getItem('collapsedSections');
		if (savedCollapsed) {
			setCollapsedSections(JSON.parse(savedCollapsed));
		}
	};

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

	const handleWorkspaceCreated = async (newWorkspace) => {
		setWorkspaces([...workspaces, newWorkspace]);

		// Add to order
		const newOrder = [...userWorkspaceOrder, newWorkspace.id];
		setUserWorkspaceOrder(newOrder);

		// Update in localStorage as fallback
		localStorage.setItem('workspaceOrder', JSON.stringify(newOrder));

		// Update via API
		try {
			await api.updateWorkspaceOrder(newOrder);
		} catch (err) {
			console.error('Error updating workspace order:', err);
		}
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
		const isFavorite = favoriteWorkspaces.includes(workspace.id);

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
					icon: isFavorite ? <FiStar /> : <FiStar />,
					onClick: () => {
						toggleFavoriteWorkspace(workspace.id);
					},
				},
				{
					label: 'Rename',
					icon: <FiEdit2 />,
					onClick: () => {
						// Replace with your rename logic
						alert('Rename functionality would open here');
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
					label: 'Move up',
					icon: <FiChevronsUp />,
					onClick: () => {
						if (index > 0) {
							moveWorkspace(index, index - 1);
						}
					},
				},
				{
					label: 'Move down',
					icon: <FiChevronsDown />,
					onClick: () => {
						if (index < workspaces.length - 1) {
							moveWorkspace(index, index + 1);
						}
					},
				},
				{
					label: 'Delete workspace',
					icon: <FiTrash2 />,
					onClick: () => {
						if (
							window.confirm(
								`Are you sure you want to delete ${workspace.name}?`
							)
						) {
							handleDeleteWorkspace(workspace.id);
						}
					},
				},
			],
		});
	};

	// Toggle workspace favorite status
	const toggleFavoriteWorkspace = (workspaceId) => {
		const newFavorites = favoriteWorkspaces.includes(workspaceId)
			? favoriteWorkspaces.filter((id) => id !== workspaceId)
			: [...favoriteWorkspaces, workspaceId];

		setFavoriteWorkspaces(newFavorites);
		localStorage.setItem('favoriteWorkspaces', JSON.stringify(newFavorites));
	};

	// Toggle workspace private status
	const togglePrivateWorkspace = (workspaceId) => {
		const newPrivate = privateWorkspaces.includes(workspaceId)
			? privateWorkspaces.filter((id) => id !== workspaceId)
			: [...privateWorkspaces, workspaceId];

		setPrivateWorkspaces(newPrivate);
		localStorage.setItem('privateWorkspaces', JSON.stringify(newPrivate));
	};

	// Handle workspace deletion
	const handleDeleteWorkspace = async (id) => {
		try {
			await api.deleteWorkspace(id);

			// Update state
			setWorkspaces(workspaces.filter((w) => w.id !== id));

			// Update order
			const newOrder = userWorkspaceOrder.filter((wsId) => wsId !== id);
			setUserWorkspaceOrder(newOrder);
			localStorage.setItem('workspaceOrder', JSON.stringify(newOrder));

			// Remove from favorites and private if present
			if (favoriteWorkspaces.includes(id)) {
				const newFavs = favoriteWorkspaces.filter((wsId) => wsId !== id);
				setFavoriteWorkspaces(newFavs);
				localStorage.setItem('favoriteWorkspaces', JSON.stringify(newFavs));
			}

			if (privateWorkspaces.includes(id)) {
				const newPrivate = privateWorkspaces.filter((wsId) => wsId !== id);
				setPrivateWorkspaces(newPrivate);
				localStorage.setItem('privateWorkspaces', JSON.stringify(newPrivate));

				// Update private workspaces via API
				try {
					await api.updatePrivateWorkspaces(newPrivate);
				} catch (err) {
					console.error('Error updating private workspaces:', err);
				}
			}

			// Navigate to dashboard if current workspace is deleted
			if (currentWorkspace && currentWorkspace.id === id) {
				navigate('/dashboard');
			}
		} catch (err) {
			console.error('Error deleting workspace:', err);
			alert('Failed to delete workspace. Please try again.');
		}
	};

	// Move workspace in order
	const moveWorkspace = async (fromIndex, toIndex) => {
		// Get the actual workspace IDs based on the current display order
		const sortedWorkspaces = getSortedWorkspaces();
		const orderedIds = sortedWorkspaces.map((w) => w.id);

		const newOrder = [...orderedIds];
		const [movedItem] = newOrder.splice(fromIndex, 1);
		newOrder.splice(toIndex, 0, movedItem);

		setUserWorkspaceOrder(newOrder);

		// Update in localStorage as fallback
		localStorage.setItem('workspaceOrder', JSON.stringify(newOrder));

		// Update via API
		try {
			await api.updateWorkspaceOrder(newOrder);
		} catch (err) {
			console.error('Error updating workspace order:', err);
		}
	};

	// Toggle section collapse
	const toggleSectionCollapse = async (section) => {
		const newCollapsed = {
			...collapsedSections,
			[section]: !collapsedSections[section],
		};
		setCollapsedSections(newCollapsed);

		// Update in localStorage as fallback
		localStorage.setItem('collapsedSections', JSON.stringify(newCollapsed));

		// Update via API
		try {
			await api.updateCollapsedSections(newCollapsed);
		} catch (err) {
			console.error('Error updating collapsed sections:', err);
		}
	};

	// Get workspaces sorted by user order
	const getSortedWorkspaces = () => {
		// Make a copy of workspaces to sort
		const workspacesCopy = [...workspaces];

		// Sort by user's preferred order
		return workspacesCopy.sort((a, b) => {
			const indexA = userWorkspaceOrder.indexOf(a.id);
			const indexB = userWorkspaceOrder.indexOf(b.id);

			// If workspace doesn't exist in order, put it at the end
			if (indexA === -1) return 1;
			if (indexB === -1) return -1;

			return indexA - indexB;
		});
	};

	// Get favorite workspaces
	const getFavoriteWorkspaces = () => {
		return workspaces.filter((ws) => favoriteWorkspaces.includes(ws.id));
	};

	// Get private workspaces
	const getPrivateWorkspaces = () => {
		return workspaces.filter((ws) => privateWorkspaces.includes(ws.id));
	};

	// Get regular workspaces (not private or favorites)
	const getRegularWorkspaces = () => {
		const sorted = getSortedWorkspaces();
		return sorted.filter(
			(ws) =>
				!favoriteWorkspaces.includes(ws.id) &&
				!privateWorkspaces.includes(ws.id)
		);
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

	// Render section header with collapse toggle
	const renderSectionHeader = (title, sectionKey, count) => (
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
				{title} {count > 0 && <span className='ml-1'>({count})</span>}
			</h3>
			{sectionKey === 'workspaces' && (
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
	);

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
						{!sidebarCollapsed && renderNavigation()}

						{/* If we're at dashboard level, show workspaces */}
						{navigationStack.length === 0 && (
							<>
								{/* Favorite workspaces section */}
								{!sidebarCollapsed && getFavoriteWorkspaces().length > 0 && (
									<>
										{renderSectionHeader(
											'Favorites',
											'favorites',
											getFavoriteWorkspaces().length
										)}

										{!collapsedSections.favorites && (
											<div className='space-y-1 mb-5'>
												{getFavoriteWorkspaces().map((workspace, index) => (
													<Link
														key={workspace.id}
														to={`/workspaces/${workspace.id}`}
													>
														<DraggableWorkspaceItem
															workspace={workspace}
															index={index}
															moveWorkspace={moveWorkspace}
															isPrivate={privateWorkspaces.includes(
																workspace.id
															)}
															isSelected={
																workspaceId === workspace.id.toString()
															}
															onContextMenu={(e) =>
																handleWorkspaceContextMenu(e, workspace, index)
															}
														/>
													</Link>
												))}
											</div>
										)}
									</>
								)}

								{/* Regular workspaces section */}
								{!sidebarCollapsed && (
									<>
										{renderSectionHeader(
											'Workspaces',
											'workspaces',
											getRegularWorkspaces().length
										)}

										{!collapsedSections.workspaces && (
											<div className='space-y-1 mb-5'>
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
														{getRegularWorkspaces().length === 0 ? (
															<div className='text-center py-4 text-gray-500 text-sm'>
																No workspaces found
															</div>
														) : (
															getRegularWorkspaces().map((workspace, index) => (
																<Link
																	key={workspace.id}
																	to={`/workspaces/${workspace.id}`}
																>
																	<DraggableWorkspaceItem
																		workspace={workspace}
																		index={index}
																		moveWorkspace={moveWorkspace}
																		isPrivate={false}
																		isSelected={
																			workspaceId === workspace.id.toString()
																		}
																		onContextMenu={(e) =>
																			handleWorkspaceContextMenu(
																				e,
																				workspace,
																				index
																			)
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
								)}

								{/* Private workspaces section */}
								{!sidebarCollapsed && getPrivateWorkspaces().length > 0 && (
									<>
										{renderSectionHeader(
											'Private',
											'private',
											getPrivateWorkspaces().length
										)}

										{!collapsedSections.private && (
											<div className='space-y-1 mb-5'>
												{getPrivateWorkspaces().map((workspace, index) => (
													<Link
														key={workspace.id}
														to={`/workspaces/${workspace.id}`}
													>
														<DraggableWorkspaceItem
															workspace={workspace}
															index={index}
															moveWorkspace={moveWorkspace}
															isPrivate={true}
															isSelected={
																workspaceId === workspace.id.toString()
															}
															onContextMenu={(e) =>
																handleWorkspaceContextMenu(e, workspace, index)
															}
														/>
													</Link>
												))}
											</div>
										)}
									</>
								)}

								{/* When sidebar is collapsed, just show icons */}
								{sidebarCollapsed && (
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
								)}
							</>
						)}

						{/* If we're viewing a workspace, show its projects */}
						{navigationStack.length === 1 &&
							navigationStack[0].type === 'workspace' && (
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
																<span
																	className={
																		sidebarCollapsed ? 'hidden' : 'truncate'
																	}
																>
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
							)}

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

export default Sidebar;
