import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/api';

// Import icons
import {
	FiPlus,
	FiFolder,
	FiClock,
	FiUsers,
	FiMusic,
	FiX,
	FiAlertCircle,
} from 'react-icons/fi';

// Import components
import Spinner from '../components/common/Spinner';

const DashboardPage = ({ sidebarOpen, setSidebarOpen }) => {
	const { currentUser } = useAuth();
	const [workspaces, setWorkspaces] = useState([]);
	const [recentProjects, setRecentProjects] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [activeTab, setActiveTab] = useState('workspaces');
	const [showCreateModal, setShowCreateModal] = useState(false);
	const [newWorkspace, setNewWorkspace] = useState({
		name: '',
		description: '',
		workspace_type: 'production',
		visibility: 'private',
	});

	useEffect(() => {
		const fetchData = async () => {
			try {
				setLoading(true);

				// First, check if our debug endpoint works
				try {
					const debugResponse = await api.axiosInstance.get('/api/v1/debug');
					console.log('Debug endpoint response:', debugResponse.data);
				} catch (debugErr) {
					console.error('Debug endpoint error:', debugErr);
				}

				// Try to fetch current user info
				try {
					const userResponse = await api.axiosInstance.get(
						'/api/v1/debug/current_user'
					);
					console.log('Current user info:', userResponse.data);
				} catch (userErr) {
					console.error('User info error:', userErr);
				}

				// Now try to fetch workspaces with more detailed error handling
				try {
					const workspacesResponse = await api.getWorkspaces();
					console.log('Workspaces response:', workspacesResponse.data);
					setWorkspaces(workspacesResponse.data || []);
				} catch (workspaceErr) {
					console.error('Workspace fetch error:', workspaceErr);
					console.error(
						'Workspace error response:',
						workspaceErr.response?.data
					);
					setWorkspaces([]);
				}

				// Try to fetch recent projects using the dedicated endpoint
				try {
					const recentProjectsResponse = await api.getRecentProjects();
					console.log('Recent projects response:', recentProjectsResponse.data);
					setRecentProjects(recentProjectsResponse.data || []);
				} catch (projectsErr) {
					console.error('Projects fetch error:', projectsErr);
					console.error('Projects error response:', projectsErr.response?.data);
					setRecentProjects([]);
				}

				setError(null);
			} catch (err) {
				console.error('Error fetching dashboard data:', err);
				if (err.response) {
					console.error('Error response data:', err.response.data);
					console.error('Error response status:', err.response.status);
					console.error('Error response headers:', err.response.headers);
				}
				setError(`Failed to load dashboard data: ${err.message}`);
			} finally {
				setLoading(false);
			}
		};

		fetchData();
	}, []);

	const handleCreateWorkspace = async (e) => {
		e.preventDefault();

		try {
			setLoading(true);
			// Send the new workspace to the API
			const response = await api.createWorkspace(newWorkspace);

			// Update the workspaces state with the new workspace
			setWorkspaces([...workspaces, response.data]);
			setShowCreateModal(false);

			// Reset the form
			setNewWorkspace({
				name: '',
				description: '',
				workspace_type: 'production',
				visibility: 'private',
			});
		} catch (err) {
			console.error('Error creating workspace:', err);
			setError('Failed to create workspace. Please try again.');
		} finally {
			setLoading(false);
		}
	};

	const handleInputChange = (e) => {
		const { name, value } = e.target;
		setNewWorkspace({
			...newWorkspace,
			[name]: value,
		});
	};

	// Function to get workspace type badge color
	const getWorkspaceTypeColor = (type) => {
		switch (type) {
			case 'production':
				return 'bg-ableton-blue-500/20 text-ableton-blue-300';
			case 'songwriting':
				return 'bg-ableton-purple-500/20 text-ableton-purple-300';
			case 'mixing':
				return 'bg-green-500/20 text-green-300';
			case 'mastering':
				return 'bg-yellow-500/20 text-yellow-300';
			default:
				return 'bg-gray-500/20 text-gray-300';
		}
	};

	// Loading state
	if (loading) {
		return (
			<div className='min-h-screen flex items-center justify-center bg-ableton-dark-400'>
				<div className='flex flex-col items-center'>
					<Spinner
						size='lg'
						color='blue'
					/>
					<p className='text-gray-400 mt-4'>Loading your dashboard...</p>
				</div>
			</div>
		);
	}

	// Error state
	if (error) {
		return (
			<div className='min-h-screen flex items-center justify-center bg-ableton-dark-400 px-4'>
				<div className='bg-red-500/10 border border-red-500/30 rounded-lg p-4 max-w-md w-full'>
					<h2 className='text-red-500 text-lg font-semibold mb-2 flex items-center'>
						<FiAlertCircle className='w-5 h-5 mr-2' />
						Error Loading Dashboard
					</h2>
					<p className='text-gray-300'>{error}</p>
					<button
						className='mt-4 px-4 py-2 bg-ableton-dark-300 text-white rounded-md hover:bg-ableton-dark-200 transition-colors'
						onClick={() => window.location.reload()}
					>
						Try Again
					</button>
				</div>
			</div>
		);
	}

	return (
		<div className='min-h-screen bg-ableton-dark-400 text-gray-200'>
			<main
				className={`transition-all duration-300 ${
					sidebarOpen ? 'ml-64' : 'ml-0'
				}`}
			>
				<div className='container mx-auto px-4 py-8 max-w-7xl'>
					{/* Dashboard Header */}
					<div className='flex flex-col md:flex-row md:items-center md:justify-between mb-8'>
						<div>
							<h1 className='text-2xl md:text-3xl font-bold text-white'>
								Dashboard
							</h1>
							<p className='text-gray-400 mt-1'>
								Welcome back, {currentUser?.username || 'User'}
							</p>
						</div>
						<button
							onClick={() => setShowCreateModal(true)}
							className='mt-4 md:mt-0 flex items-center px-4 py-2 bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white rounded-md transition-colors'
						>
							<FiPlus className='w-5 h-5 mr-2' />
							New Workspace
						</button>
					</div>

					{/* Tabs */}
					<div className='border-b border-ableton-dark-200 mb-6'>
						<div className='flex space-x-8'>
							<button
								className={`py-4 px-1 flex items-center ${
									activeTab === 'workspaces'
										? 'text-ableton-blue-400 border-b-2 border-ableton-blue-400 font-medium'
										: 'text-gray-400 hover:text-gray-300'
								}`}
								onClick={() => setActiveTab('workspaces')}
							>
								<FiFolder className='w-5 h-5 mr-2' />
								<span>My Workspaces</span>
							</button>
							<button
								className={`py-4 px-1 flex items-center ${
									activeTab === 'recent'
										? 'text-ableton-blue-400 border-b-2 border-ableton-blue-400 font-medium'
										: 'text-gray-400 hover:text-gray-300'
								}`}
								onClick={() => setActiveTab('recent')}
							>
								<FiClock className='w-5 h-5 mr-2' />
								<span>Recent Projects</span>
							</button>
						</div>
					</div>

					{/* Content */}
					<div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6'>
						{activeTab === 'workspaces' &&
							workspaces.map((workspace) => (
								<div
									key={workspace.id}
									className='bg-ableton-dark-300 rounded-xl overflow-hidden shadow-lg border border-ableton-dark-200 hover:border-ableton-dark-100 transition-colors'
								>
									<div className='h-3 bg-gradient-to-r from-ableton-blue-500 to-ableton-purple-500'></div>
									<div className='p-6'>
										<div className='flex justify-between items-start mb-3'>
											<h3 className='text-xl font-semibold text-white'>
												{workspace.name}
											</h3>
											<span
												className={`text-xs px-2 py-1 rounded-full ${getWorkspaceTypeColor(
													workspace.workspace_type
												)}`}
											>
												{workspace.workspace_type}
											</span>
										</div>
										<p className='text-gray-400 text-sm mb-4 line-clamp-2 h-10'>
											{workspace.description}
										</p>
										<div className='flex justify-between items-center text-sm text-gray-500 mb-5'>
											<div className='flex items-center'>
												<FiMusic className='w-4 h-4 mr-1' />
												<span>{workspace.project_count} projects</span>
											</div>
											<div>
												Created{' '}
												{new Date(workspace.created_at).toLocaleDateString()}
											</div>
										</div>
										<Link
											to={`/workspaces/${workspace.id}`}
											className='block w-full text-center py-2 bg-ableton-dark-200 hover:bg-ableton-dark-100 text-ableton-blue-400 font-medium rounded-md transition-colors'
										>
											View Workspace
										</Link>
									</div>
								</div>
							))}

						{activeTab === 'recent' &&
							recentProjects.map((project) => (
								<div
									key={project.id}
									className='bg-ableton-dark-300 rounded-xl overflow-hidden shadow-lg border border-ableton-dark-200 hover:border-ableton-dark-100 transition-colors'
								>
									<div className='p-6'>
										<div className='flex justify-between items-start mb-2'>
											<h3 className='text-xl font-semibold text-white'>
												{project.title}
											</h3>
											<span className='bg-ableton-dark-200 text-gray-400 text-xs px-2 py-1 rounded-full'>
												{project.version_count} versions
											</span>
										</div>
										<p className='text-sm text-ableton-blue-400 mb-3'>
											{project.workspace_name}
										</p>
										<p className='text-gray-400 text-sm mb-4 line-clamp-2 h-10'>
											{project.description}
										</p>
										<div className='text-sm text-gray-500 mb-5'>
											Last updated:{' '}
											{new Date(project.updated_at).toLocaleDateString()}
										</div>
										<Link
											to={`/workspaces/${project.workspace_id}/projects/${project.id}`}
											className='block w-full text-center py-2 bg-ableton-dark-200 hover:bg-ableton-dark-100 text-ableton-blue-400 font-medium rounded-md transition-colors'
										>
											Open Project
										</Link>
									</div>
								</div>
							))}
					</div>

					{/* Empty State */}
					{activeTab === 'workspaces' && workspaces.length === 0 && (
						<div className='bg-ableton-dark-300 rounded-xl p-8 text-center'>
							<div className='bg-ableton-dark-200 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4'>
								<FiFolder className='w-8 h-8 text-gray-400' />
							</div>
							<h3 className='text-xl font-semibold text-white mb-2'>
								No workspaces yet
							</h3>
							<p className='text-gray-400 mb-6 max-w-md mx-auto'>
								Create your first workspace to start organizing your music
								projects
							</p>
							<button
								onClick={() => setShowCreateModal(true)}
								className='px-4 py-2 bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white rounded-md transition-colors'
							>
								Create Workspace
							</button>
						</div>
					)}

					{activeTab === 'recent' && recentProjects.length === 0 && (
						<div className='bg-ableton-dark-300 rounded-xl p-8 text-center'>
							<div className='bg-ableton-dark-200 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4'>
								<FiMusic className='w-8 h-8 text-gray-400' />
							</div>
							<h3 className='text-xl font-semibold text-white mb-2'>
								No recent projects
							</h3>
							<p className='text-gray-400 mb-6 max-w-md mx-auto'>
								Your recent projects will appear here once you create them
							</p>
							<button
								onClick={() => setActiveTab('workspaces')}
								className='px-4 py-2 bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white rounded-md transition-colors'
							>
								Go to Workspaces
							</button>
						</div>
					)}
				</div>
			</main>

			{/* Create Workspace Modal */}
			{showCreateModal && (
				<div className='fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50'>
					<div className='bg-ableton-dark-300 rounded-xl w-full max-w-md shadow-2xl'>
						<div className='flex justify-between items-center p-6 border-b border-ableton-dark-200'>
							<h2 className='text-xl font-semibold text-white'>
								Create New Workspace
							</h2>
							<button
								onClick={() => setShowCreateModal(false)}
								className='text-gray-400 hover:text-white transition-colors'
							>
								<FiX className='w-6 h-6' />
							</button>
						</div>

						<form
							onSubmit={handleCreateWorkspace}
							className='p-6'
						>
							<div className='mb-4'>
								<label
									htmlFor='name'
									className='block text-sm text-gray-400 mb-1.5'
								>
									Workspace Name <span className='text-red-500'>*</span>
								</label>
								<input
									type='text'
									id='name'
									name='name'
									value={newWorkspace.name}
									onChange={handleInputChange}
									placeholder='My Production Workspace'
									className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
									required
								/>
							</div>

							<div className='mb-4'>
								<label
									htmlFor='description'
									className='block text-sm text-gray-400 mb-1.5'
								>
									Description
								</label>
								<textarea
									id='description'
									name='description'
									value={newWorkspace.description}
									onChange={handleInputChange}
									placeholder='What is this workspace for?'
									className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all min-h-[100px]'
								></textarea>
							</div>

							<div className='mb-4'>
								<label
									htmlFor='workspace_type'
									className='block text-sm text-gray-400 mb-1.5'
								>
									Workspace Type
								</label>
								<select
									id='workspace_type'
									name='workspace_type'
									value={newWorkspace.workspace_type}
									onChange={handleInputChange}
									className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 transition-all'
								>
									<option value='production'>Production</option>
									<option value='songwriting'>Songwriting</option>
									<option value='mixing'>Mixing</option>
									<option value='mastering'>Mastering</option>
									<option value='other'>Other</option>
								</select>
							</div>

							<div className='mb-6'>
								<label
									htmlFor='visibility'
									className='block text-sm text-gray-400 mb-1.5'
								>
									Visibility
								</label>
								<select
									id='visibility'
									name='visibility'
									value={newWorkspace.visibility}
									onChange={handleInputChange}
									className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 transition-all'
								>
									<option value='private'>Private</option>
									<option value='public'>Public</option>
								</select>
								<p className='mt-1 text-xs text-gray-500'>
									{newWorkspace.visibility === 'private'
										? 'Only you and people you invite can access this workspace'
										: 'Anyone with the link can view this workspace'}
								</p>
							</div>

							<div className='flex space-x-3'>
								<button
									type='button'
									onClick={() => setShowCreateModal(false)}
									className='flex-1 py-3 bg-ableton-dark-200 hover:bg-ableton-dark-100 text-white rounded-md transition-colors'
								>
									Cancel
								</button>
								<button
									type='submit'
									className='flex-1 py-3 bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white rounded-md transition-colors'
								>
									Create Workspace
								</button>
							</div>
						</form>
					</div>
				</div>
			)}
		</div>
	);
};

export default DashboardPage;
