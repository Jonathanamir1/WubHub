import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useParams, useLocation } from 'react-router-dom';
import { FiPlus, FiFolder, FiMusic, FiHome, FiSettings } from 'react-icons/fi';
import api from '../../services/api';
import { useAuth } from '../../contexts/AuthContext';
import Spinner from '../common/Spinner';

const Sidebar = () => {
	const { currentUser } = useAuth();
	const [workspaces, setWorkspaces] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const navigate = useNavigate();
	const { workspaceId } = useParams();
	const location = useLocation();

	useEffect(() => {
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

		fetchWorkspaces();
	}, [location.pathname]); // Refresh when path changes to update active states

	// Get workspace type color for badges
	const getWorkspaceTypeColor = (type) => {
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
		navigate('/dashboard', { state: { openCreateModal: true } });
	};

	return (
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
						<div className='text-center py-4 text-red-400 text-sm'>{error}</div>
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
										<span
											className={`text-xs px-1.5 py-0.5 rounded-full border ${getWorkspaceTypeColor(
												workspace.workspace_type
											)}`}
										>
											{workspace.project_count}
										</span>
									</Link>
								))
							)}
						</>
					)}
				</div>

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
	);
};

export default Sidebar;
