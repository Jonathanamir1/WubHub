// frontend/src/pages/WorkspacePage.jsx
import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import {
	FiPlus,
	FiSettings,
	FiUsers,
	FiAlertCircle,
	FiFolder,
	FiEdit,
	FiTrash2,
	FiChevronLeft,
} from 'react-icons/fi';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/api';
import CreateProjectModal from '../components/projects/CreateProjectModal';
import DeleteConfirmModal from '../components/common/DeleteConfirmModal';

const WorkspacePage = () => {
	const { workspaceId } = useParams();
	const navigate = useNavigate();
	const { currentUser } = useAuth();

	// State variables
	const [workspace, setWorkspace] = useState(null);
	const [projects, setProjects] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [isOwner, setIsOwner] = useState(false);
	const [showCreateProjectModal, setShowCreateProjectModal] = useState(false);
	const [showDeleteWorkspaceModal, setShowDeleteWorkspaceModal] =
		useState(false);

	// Fetch workspace and projects
	useEffect(() => {
		const fetchWorkspaceData = async () => {
			try {
				setLoading(true);

				// Fetch workspace data
				const workspaceResponse = await api.getWorkspace(workspaceId);
				const workspaceData = workspaceResponse.data;

				setWorkspace(workspaceData);
				setIsOwner(workspaceData.user_id === currentUser?.id);

				// Fetch projects for this workspace
				const projectsResponse = await api.getProjects(workspaceId);
				setProjects(projectsResponse.data || []);

				setError(null);
			} catch (err) {
				console.error('Error fetching workspace data:', err);
				setError('Failed to load workspace. Please try again later.');
			} finally {
				setLoading(false);
			}
		};

		fetchWorkspaceData();
	}, [workspaceId, currentUser?.id]);

	// Handle project creation
	const handleProjectCreated = (newProject) => {
		setProjects([...projects, newProject]);
	};

	// Handle workspace deletion
	const handleDeleteWorkspace = async () => {
		try {
			await api.deleteWorkspace(workspaceId);
			navigate('/dashboard');
		} catch (err) {
			console.error('Error deleting workspace:', err);
			setError('Failed to delete workspace. Please try again.');
		}
	};

	// Loading state
	if (loading) {
		return (
			<div className='flex justify-center items-center h-64'>
				<div className='animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-ableton-blue-500'></div>
			</div>
		);
	}

	// Error state
	if (error) {
		return (
			<div className='p-4 bg-red-500/10 border border-red-500/30 rounded-md text-red-500'>
				<div className='flex items-center mb-2'>
					<FiAlertCircle className='w-5 h-5 mr-2' />
					<h3 className='font-medium'>Error</h3>
				</div>
				<p>{error}</p>
			</div>
		);
	}

	// Not found state
	if (!workspace) {
		return (
			<div className='p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-md text-yellow-500'>
				<div className='flex items-center mb-2'>
					<FiAlertCircle className='w-5 h-5 mr-2' />
					<h3 className='font-medium'>Workspace Not Found</h3>
				</div>
				<p>
					The workspace you are looking for does not exist or you don't have
					permission to view it.
				</p>
			</div>
		);
	}

	return (
		<div className='container mx-auto px-4 py-6'>
			{/* Back button */}
			<Link
				to='/dashboard'
				className='inline-flex items-center text-gray-400 hover:text-white mb-6'
			>
				<FiChevronLeft className='mr-1' /> Back to Dashboard
			</Link>

			{/* Workspace header */}
			<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200 mb-6'>
				<div className='flex flex-col md:flex-row justify-between items-start'>
					<div>
						<h1 className='text-2xl font-bold'>{workspace.name}</h1>

						<div className='flex items-center mt-1 space-x-3'>
							<span className='bg-ableton-blue-500/20 text-ableton-blue-300 border border-ableton-blue-500/30 px-2 py-0.5 rounded-full text-xs'>
								{workspace.visibility}
							</span>
						</div>

						{workspace.description && (
							<p className='mt-3 text-gray-300'>{workspace.description}</p>
						)}
					</div>

					{isOwner && (
						<div className='flex mt-3 md:mt-0'>
							<button
								onClick={() => navigate(`/workspaces/${workspaceId}/settings`)}
								className='flex items-center px-3 py-1.5 bg-ableton-dark-200 hover:bg-ableton-dark-100 rounded-md text-sm mr-2 transition-colors'
							>
								<FiEdit className='mr-1.5' /> Edit
							</button>

							<button
								onClick={() => setShowDeleteWorkspaceModal(true)}
								className='flex items-center px-3 py-1.5 bg-red-500/20 text-red-400 hover:bg-red-500/30 rounded-md text-sm transition-colors'
							>
								<FiTrash2 className='mr-1.5' /> Delete
							</button>
						</div>
					)}
				</div>
			</div>

			{/* Projects section */}
			<div className='mb-6'>
				<div className='flex justify-between items-center mb-4'>
					<h2 className='text-xl font-semibold'>Projects</h2>
					<button
						onClick={() => setShowCreateProjectModal(true)}
						className='flex items-center px-3 py-1.5 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md text-sm transition-colors'
					>
						<FiPlus className='mr-1.5' /> New Project
					</button>
				</div>

				{projects.length > 0 ? (
					<div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4'>
						{projects.map((project) => (
							<Link
								key={project.id}
								to={`/workspaces/${workspaceId}/projects/${project.id}`}
								className='block'
							>
								<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200 hover:border-ableton-blue-500/50 transition-colors h-full'>
									<div className='flex items-start justify-between'>
										<div className='flex items-center'>
											<FiFolder className='w-5 h-5 mr-2 text-ableton-blue-400' />
											<h3 className='font-medium text-lg'>{project.title}</h3>
										</div>
										<span className='bg-ableton-blue-500/20 text-ableton-blue-300 border border-ableton-blue-500/30 px-2 py-0.5 rounded-full text-xs'>
											{project.visibility}
										</span>
									</div>

									{project.description && (
										<p className='mt-2 text-gray-400 text-sm line-clamp-2'>
											{project.description}
										</p>
									)}

									<div className='mt-4 text-xs text-gray-500'>
										Created: {new Date(project.created_at).toLocaleDateString()}
									</div>
								</div>
							</Link>
						))}
					</div>
				) : (
					<div className='bg-ableton-dark-300 rounded-md p-8 border border-ableton-dark-200 text-center'>
						<h3 className='text-lg font-medium mb-2'>No Projects Yet</h3>
						<p className='text-gray-400 mb-4'>
							This workspace doesn't have any projects yet. Create your first
							project to get started.
						</p>
						<button
							onClick={() => setShowCreateProjectModal(true)}
							className='inline-flex items-center px-4 py-2 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md transition-colors'
						>
							<FiPlus className='mr-1.5' /> Create Project
						</button>
					</div>
				)}
			</div>

			{/* Create Project Modal */}
			{showCreateProjectModal && (
				<CreateProjectModal
					workspaceId={workspaceId}
					isOpen={showCreateProjectModal}
					onClose={() => setShowCreateProjectModal(false)}
					onProjectCreated={handleProjectCreated}
				/>
			)}

			{/* Delete Workspace Modal */}
			{showDeleteWorkspaceModal && (
				<DeleteConfirmModal
					show={showDeleteWorkspaceModal}
					onClose={() => setShowDeleteWorkspaceModal(false)}
					onConfirm={handleDeleteWorkspace}
					title='Delete Workspace'
					message='Are you sure you want to delete this workspace? All projects and data within this workspace will be permanently deleted. This action cannot be undone.'
					confirmText='Delete Workspace'
				/>
			)}
		</div>
	);
};

export default WorkspacePage;
