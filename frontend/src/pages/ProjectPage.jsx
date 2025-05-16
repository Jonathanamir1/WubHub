// frontend/src/pages/ProjectPage.jsx
import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import {
	FiChevronLeft,
	FiEdit,
	FiTrash2,
	FiPlus,
	FiAlertCircle,
} from 'react-icons/fi';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/api';
import DeleteConfirmModal from '../components/common/DeleteConfirmModal';

const ProjectPage = () => {
	const { workspaceId, projectId } = useParams();
	const navigate = useNavigate();
	const { currentUser } = useAuth();

	// State variables
	const [project, setProject] = useState(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [isOwner, setIsOwner] = useState(false);
	const [showDeleteModal, setShowDeleteModal] = useState(false);

	// Fetch project data
	useEffect(() => {
		const fetchProject = async () => {
			try {
				setLoading(true);
				const response = await api.getProject(workspaceId, projectId);
				const projectData = response.data;

				setProject(projectData);
				setIsOwner(projectData.user_id === currentUser?.id);
				setError(null);
			} catch (err) {
				console.error('Error fetching project:', err);
				setError('Failed to load project. Please try again later.');
			} finally {
				setLoading(false);
			}
		};

		fetchProject();
	}, [projectId, workspaceId, currentUser?.id]);

	// Handle delete project
	const handleDeleteProject = async () => {
		try {
			await api.deleteProject(workspaceId, projectId);
			navigate(`/workspaces/${workspaceId}`);
		} catch (err) {
			console.error('Error deleting project:', err);
			setError('Failed to delete project. Please try again.');
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
	if (!project) {
		return (
			<div className='p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-md text-yellow-500'>
				<div className='flex items-center mb-2'>
					<FiAlertCircle className='w-5 h-5 mr-2' />
					<h3 className='font-medium'>Project Not Found</h3>
				</div>
				<p>
					The project you are looking for does not exist or you don't have
					permission to view it.
				</p>
			</div>
		);
	}

	return (
		<div className='container mx-auto px-4 py-6'>
			{/* Back button */}
			<Link
				to={`/workspaces/${workspaceId}`}
				className='inline-flex items-center text-gray-400 hover:text-white mb-6'
			>
				<FiChevronLeft className='mr-1' /> Back to Workspace
			</Link>

			{/* Project header */}
			<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200 mb-6'>
				<div className='flex flex-col md:flex-row justify-between items-start'>
					<div>
						<h1 className='text-2xl font-bold'>{project.title}</h1>

						<div className='flex items-center mt-1 space-x-3'>
							<span className='bg-ableton-blue-500/20 text-ableton-blue-300 border border-ableton-blue-500/30 px-2 py-0.5 rounded-full text-xs'>
								{project.visibility}
							</span>

							<span className='text-gray-400 text-sm'>
								Created {new Date(project.created_at).toLocaleDateString()}
							</span>
						</div>

						{project.description && (
							<p className='mt-3 text-gray-300'>{project.description}</p>
						)}
					</div>

					{isOwner && (
						<div className='flex mt-3 md:mt-0'>
							<button
								onClick={() =>
									navigate(
										`/workspaces/${workspaceId}/projects/${projectId}/edit`
									)
								}
								className='flex items-center px-3 py-1.5 bg-ableton-dark-200 hover:bg-ableton-dark-100 rounded-md text-sm mr-2 transition-colors'
							>
								<FiEdit className='mr-1.5' /> Edit
							</button>

							<button
								onClick={() => setShowDeleteModal(true)}
								className='flex items-center px-3 py-1.5 bg-red-500/20 text-red-400 hover:bg-red-500/30 rounded-md text-sm transition-colors'
							>
								<FiTrash2 className='mr-1.5' /> Delete
							</button>
						</div>
					)}
				</div>
			</div>

			{/* Empty state - Content to be added as features are developed */}
			<div className='bg-ableton-dark-300 rounded-md p-8 border border-ableton-dark-200 text-center'>
				<h2 className='text-xl font-medium mb-3'>Project Content</h2>
				<p className='text-gray-400 mb-6'>
					This is where your project content will appear. Start by creating
					tracks, uploading files, or adding collaborators.
				</p>
				<button className='inline-flex items-center px-4 py-2 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md transition-colors'>
					<FiPlus className='mr-1.5' /> Add Content
				</button>
			</div>

			{/* Delete confirmation modal */}
			{showDeleteModal && (
				<DeleteConfirmModal
					show={showDeleteModal}
					onClose={() => setShowDeleteModal(false)}
					onConfirm={handleDeleteProject}
					title='Delete Project'
					message='Are you sure you want to delete this project? This action cannot be undone and all data will be permanently lost.'
					confirmText='Delete Project'
				/>
			)}
		</div>
	);
};

export default ProjectPage;
