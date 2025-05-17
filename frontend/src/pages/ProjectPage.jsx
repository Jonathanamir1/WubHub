// frontend/src/pages/ProjectPage.jsx
import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import {
	FiChevronLeft,
	FiEdit,
	FiTrash2,
	FiPlus,
	FiAlertCircle,
	FiFolder,
	FiMusic,
	FiUsers,
	FiSettings,
	FiClock,
	FiHelpCircle,
	FiLayout,
	FiUpload,
	FiDownload,
	FiEye,
} from 'react-icons/fi';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/api';
import DeleteConfirmModal from '../components/common/DeleteConfirmModal';
import FolderManager from '../components/folders/FolderManager';
import FolderBrowser from '../components/folders/FolderBrowser';
import AudioPlayer from '../components/audio/AudioPlayer';
import BatchUploadModal from '../components/folders/BatchUploadModal';
import VersionsList from '../components/projects/VersionsList';
import CollaboratorsList from '../components/projects/CollaboratorsList';
import CreateVersionModal from '../components/projects/CreateVersionModal';
import ProjectHeader from '../components/projects/ProjectHeader';

const ProjectPage = () => {
	const { workspaceId, projectId } = useParams();
	const navigate = useNavigate();
	const { currentUser } = useAuth();

	// State variables
	const [project, setProject] = useState(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [isOwner, setIsOwner] = useState(false);
	const [activeTab, setActiveTab] = useState('folders');
	const [showDeleteModal, setShowDeleteModal] = useState(false);
	const [selectedAudioFile, setSelectedAudioFile] = useState(null);
	const [trackVersions, setTrackVersions] = useState([]);
	const [selectedVersion, setSelectedVersion] = useState(null);
	const [collaborators, setCollaborators] = useState([]);
	const [showCreateVersionModal, setShowCreateVersionModal] = useState(false);
	const [showBatchUploadModal, setShowBatchUploadModal] = useState(false);

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
		fetchTrackVersions();
		fetchCollaborators();
	}, [projectId, workspaceId, currentUser?.id]);

	// Fetch track versions
	const fetchTrackVersions = async () => {
		try {
			const response = await api.getTrackVersions(projectId);
			setTrackVersions(response.data || []);

			// Select the first version by default if available
			if (response.data && response.data.length > 0 && !selectedVersion) {
				setSelectedVersion(response.data[0]);
			}
		} catch (err) {
			console.error('Error fetching track versions:', err);
		}
	};

	// Fetch collaborators
	const fetchCollaborators = async () => {
		try {
			const response = await api.getRoles(projectId);

			// Add the project owner as a special "owner" role
			if (project) {
				const ownerResponse = await api.getUser(project.user_id);
				const ownerData = {
					...ownerResponse.data,
					role: 'owner',
				};

				// Filter out duplicates if the owner also has another role
				const filteredCollaborators = response.data.filter(
					(c) => c.user_id !== project.user_id
				);
				setCollaborators([ownerData, ...filteredCollaborators]);
			} else {
				setCollaborators(response.data || []);
			}
		} catch (err) {
			console.error('Error fetching collaborators:', err);
		}
	};

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

	// Handle create version
	const handleCreateVersion = (versionData) => {
		setShowCreateVersionModal(false);
		fetchTrackVersions();
	};

	// Handle delete version
	const handleDeleteVersion = async (versionId) => {
		if (
			window.confirm(
				'Are you sure you want to delete this version? This action cannot be undone.'
			)
		) {
			try {
				await api.deleteTrackVersion(versionId);
				fetchTrackVersions();

				// If the deleted version was selected, clear the selection
				if (selectedVersion && selectedVersion.id === versionId) {
					setSelectedVersion(null);
				}
			} catch (err) {
				console.error('Error deleting version:', err);
				alert('Failed to delete version. Please try again.');
			}
		}
	};

	// Handle batch upload complete
	const handleBatchUploadComplete = (successCount, totalCount) => {
		setShowBatchUploadModal(false);
		alert(`Successfully uploaded ${successCount} of ${totalCount} files.`);
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
			<ProjectHeader
				project={project}
				isOwner={isOwner}
				onEdit={() =>
					navigate(`/workspaces/${workspaceId}/projects/${projectId}/edit`)
				}
				onDelete={() => setShowDeleteModal(true)}
			/>

			{/* Tabs */}
			<div className='mb-6'>
				<div className='bg-ableton-dark-300 rounded-md overflow-hidden'>
					<div className='flex border-b border-ableton-dark-200 overflow-x-auto'>
						<button
							className={`px-6 py-3 flex items-center whitespace-nowrap ${
								activeTab === 'overview'
									? 'bg-ableton-dark-200 border-b-2 border-ableton-blue-500 text-white'
									: 'text-gray-400 hover:text-white hover:bg-ableton-dark-200/50'
							}`}
							onClick={() => setActiveTab('overview')}
						>
							<FiLayout className='mr-2' /> Overview
						</button>

						<button
							className={`px-6 py-3 flex items-center whitespace-nowrap ${
								activeTab === 'folders'
									? 'bg-ableton-dark-200 border-b-2 border-ableton-blue-500 text-white'
									: 'text-gray-400 hover:text-white hover:bg-ableton-dark-200/50'
							}`}
							onClick={() => setActiveTab('folders')}
						>
							<FiFolder className='mr-2' /> Folders & Files
						</button>

						<button
							className={`px-6 py-3 flex items-center whitespace-nowrap ${
								activeTab === 'tracks'
									? 'bg-ableton-dark-200 border-b-2 border-ableton-blue-500 text-white'
									: 'text-gray-400 hover:text-white hover:bg-ableton-dark-200/50'
							}`}
							onClick={() => setActiveTab('tracks')}
						>
							<FiMusic className='mr-2' /> Tracks
						</button>

						<button
							className={`px-6 py-3 flex items-center whitespace-nowrap ${
								activeTab === 'versions'
									? 'bg-ableton-dark-200 border-b-2 border-ableton-blue-500 text-white'
									: 'text-gray-400 hover:text-white hover:bg-ableton-dark-200/50'
							}`}
							onClick={() => setActiveTab('versions')}
						>
							<FiClock className='mr-2' /> Versions
						</button>

						<button
							className={`px-6 py-3 flex items-center whitespace-nowrap ${
								activeTab === 'collaborators'
									? 'bg-ableton-dark-200 border-b-2 border-ableton-blue-500 text-white'
									: 'text-gray-400 hover:text-white hover:bg-ableton-dark-200/50'
							}`}
							onClick={() => setActiveTab('collaborators')}
						>
							<FiUsers className='mr-2' /> Collaborators
						</button>

						{isOwner && (
							<button
								className={`px-6 py-3 flex items-center whitespace-nowrap ${
									activeTab === 'settings'
										? 'bg-ableton-dark-200 border-b-2 border-ableton-blue-500 text-white'
										: 'text-gray-400 hover:text-white hover:bg-ableton-dark-200/50'
								}`}
								onClick={() => setActiveTab('settings')}
							>
								<FiSettings className='mr-2' /> Settings
							</button>
						)}
					</div>
				</div>
			</div>

			{/* Tab content */}
			<div className='mb-6'>
				{/* Overview tab */}
				{activeTab === 'overview' && (
					<div className='grid grid-cols-1 lg:grid-cols-3 gap-6'>
						<div className='lg:col-span-2 space-y-6'>
							<div className='bg-ableton-dark-300 rounded-md p-6 border border-ableton-dark-200'>
								<h2 className='text-xl font-medium mb-4'>Project Overview</h2>

								{project.description ? (
									<div className='text-gray-300'>{project.description}</div>
								) : (
									<div className='text-gray-500 italic'>
										No description provided.
									</div>
								)}

								<div className='mt-6 grid grid-cols-2 gap-4'>
									<div>
										<h3 className='text-sm text-gray-500 uppercase'>Created</h3>
										<p>{new Date(project.created_at).toLocaleDateString()}</p>
									</div>

									<div>
										<h3 className='text-sm text-gray-500 uppercase'>Updated</h3>
										<p>{new Date(project.updated_at).toLocaleDateString()}</p>
									</div>

									<div>
										<h3 className='text-sm text-gray-500 uppercase'>
											Visibility
										</h3>
										<p className='capitalize'>{project.visibility}</p>
									</div>
								</div>
							</div>

							{/* Recent activity or other project info could go here */}
						</div>

						<div className='space-y-6'>
							{/* Quick actions */}
							<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200'>
								<h3 className='text-lg font-medium mb-3'>Quick Actions</h3>

								<div className='space-y-2'>
									<button
										onClick={() => setShowBatchUploadModal(true)}
										className='w-full py-2 px-3 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md flex items-center justify-center transition-colors'
									>
										<FiUpload className='mr-2' /> Upload Files
									</button>

									<button
										onClick={() => setShowCreateVersionModal(true)}
										className='w-full py-2 px-3 bg-ableton-dark-200 hover:bg-ableton-dark-100 rounded-md flex items-center justify-center transition-colors'
									>
										<FiPlus className='mr-2' /> Create Version
									</button>

									<button
										onClick={() => setActiveTab('collaborators')}
										className='w-full py-2 px-3 bg-ableton-dark-200 hover:bg-ableton-dark-100 rounded-md flex items-center justify-center transition-colors'
									>
										<FiUsers className='mr-2' /> Manage Collaborators
									</button>
								</div>
							</div>

							{/* Latest versions */}
							{trackVersions.length > 0 && (
								<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200'>
									<h3 className='text-lg font-medium mb-3'>Recent Versions</h3>

									<div className='space-y-2'>
										{trackVersions.slice(0, 3).map((version) => (
											<div
												key={version.id}
												className='p-3 bg-ableton-dark-200 rounded-md hover:bg-ableton-dark-100 cursor-pointer'
												onClick={() => {
													setSelectedVersion(version);
													setActiveTab('versions');
												}}
											>
												<div className='font-medium'>{version.title}</div>
												<div className='text-xs text-gray-400 mt-1'>
													{new Date(version.created_at).toLocaleDateString()}
												</div>
											</div>
										))}

										{trackVersions.length > 3 && (
											<button
												onClick={() => setActiveTab('versions')}
												className='w-full text-center text-sm text-ableton-blue-400 hover:text-ableton-blue-300 py-2'
											>
												View all {trackVersions.length} versions
											</button>
										)}
									</div>
								</div>
							)}

							{/* Collaborators preview */}
							{collaborators.length > 0 && (
								<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200'>
									<h3 className='text-lg font-medium mb-3'>Collaborators</h3>

									<div className='flex flex-wrap gap-2'>
										{collaborators.map((collaborator) => (
											<div
												key={collaborator.id}
												className='flex items-center bg-ableton-dark-200 rounded-full px-3 py-1'
											>
												<div className='w-6 h-6 rounded-full bg-ableton-blue-500 flex items-center justify-center text-white font-medium text-xs mr-2'>
													{collaborator.username?.charAt(0)?.toUpperCase() ||
														'U'}
												</div>
												<span className='mr-1'>{collaborator.username}</span>
												<span className='text-xs text-gray-400'>
													({collaborator.role})
												</span>
											</div>
										))}
									</div>
								</div>
							)}
						</div>
					</div>
				)}

				{/* Folders and Files tab */}
				{activeTab === 'folders' && (
					<div className='grid grid-cols-1 lg:grid-cols-3 gap-6'>
						<div className='lg:col-span-1'>
							<FolderManager
								projectId={projectId}
								onBatchUpload={() => setShowBatchUploadModal(true)}
							/>
						</div>

						<div className='lg:col-span-2 space-y-6'>
							<FolderBrowser
								projectId={projectId}
								onSelectAudioFile={setSelectedAudioFile}
							/>

							{selectedAudioFile && (
								<AudioPlayer audioFile={selectedAudioFile} />
							)}
						</div>
					</div>
				)}

				{/* Tracks tab */}
				{activeTab === 'tracks' && (
					<div className='bg-ableton-dark-300 rounded-md p-6 border border-ableton-dark-200 text-center'>
						<h2 className='text-xl font-medium mb-4'>Tracks</h2>
						<p className='text-gray-400 mb-4'>
							This feature is coming soon. You'll be able to arrange audio files
							into tracks and sessions.
						</p>
						<button className='px-4 py-2 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md transition-colors'>
							<FiPlus className='inline mr-2' /> Create Track
						</button>
					</div>
				)}

				{/* Versions tab */}
				{activeTab === 'versions' && (
					<div className='grid grid-cols-1 lg:grid-cols-3 gap-6'>
						<div className='lg:col-span-2'>
							<VersionsList
								versions={trackVersions}
								selectedVersion={selectedVersion}
								setSelectedVersion={setSelectedVersion}
								projectId={projectId}
								isOwner={isOwner}
								currentUserId={currentUser?.id}
								onCreateVersion={() => setShowCreateVersionModal(true)}
								onDeleteVersion={handleDeleteVersion}
							/>
						</div>

						<div>
							{selectedVersion ? (
								<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200'>
									<h3 className='text-xl font-medium mb-3'>
										{selectedVersion.title}
									</h3>

									<div className='text-sm text-gray-400 mb-4'>
										Created on{' '}
										{new Date(selectedVersion.created_at).toLocaleDateString()}{' '}
										by {selectedVersion.username}
									</div>

									{selectedVersion.description && (
										<div className='mb-4 p-3 bg-ableton-dark-200 rounded-md'>
											{selectedVersion.description}
										</div>
									)}

									{/* Version actions */}
									<div className='flex flex-wrap gap-2 mt-4'>
										<button className='px-3 py-1.5 bg-ableton-blue-500 hover:bg-ableton-blue-600 rounded-md text-sm transition-colors flex items-center'>
											<FiDownload className='mr-1.5' /> Download
										</button>

										<Link
											to={`/projects/${projectId}/versions/${selectedVersion.id}`}
											className='px-3 py-1.5 bg-ableton-dark-200 hover:bg-ableton-dark-100 rounded-md text-sm transition-colors flex items-center'
										>
											<FiEye className='mr-1.5' /> View Details
										</Link>

										{(isOwner ||
											selectedVersion.user_id === currentUser?.id) && (
											<button
												onClick={() => handleDeleteVersion(selectedVersion.id)}
												className='px-3 py-1.5 bg-red-500/20 text-red-400 hover:bg-red-500/30 rounded-md text-sm transition-colors flex items-center'
											>
												<FiTrash2 className='mr-1.5' /> Delete
											</button>
										)}
									</div>
								</div>
							) : (
								<div className='bg-ableton-dark-300 rounded-md p-6 border border-ableton-dark-200 text-center'>
									<p className='text-gray-400 mb-4'>
										Select a version to view details
									</p>
								</div>
							)}
						</div>
					</div>
				)}

				{/* Collaborators tab */}
				{activeTab === 'collaborators' && (
					<CollaboratorsList
						collaborators={collaborators}
						isOwner={isOwner}
						onInvite={() => {
							/* Open invite modal */
						}}
					/>
				)}

				{/* Settings tab */}
				{activeTab === 'settings' && isOwner && (
					<div className='bg-ableton-dark-300 rounded-md p-6 border border-ableton-dark-200'>
						<h2 className='text-xl font-medium mb-6'>Project Settings</h2>

						<div className='space-y-6'>
							{/* Project information */}
							<div>
								<h3 className='text-lg mb-3'>Project Information</h3>
								<Link
									to={`/workspaces/${workspaceId}/projects/${projectId}/edit`}
									className='px-4 py-2 bg-ableton-dark-200 hover:bg-ableton-dark-100 rounded-md text-sm transition-colors inline-flex items-center'
								>
									<FiEdit className='mr-1.5' /> Edit Project Details
								</Link>
							</div>

							{/* Danger zone */}
							<div className='p-4 border border-red-500/30 rounded-md bg-red-500/10'>
								<h3 className='text-lg text-red-400 mb-3'>Danger Zone</h3>
								<p className='mb-3 text-gray-400'>
									Once you delete a project, there is no going back. Please be
									certain.
								</p>

								<button
									onClick={() => setShowDeleteModal(true)}
									className='px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-md text-sm transition-colors inline-flex items-center'
								>
									<FiTrash2 className='mr-1.5' /> Delete Project
								</button>
							</div>
						</div>
					</div>
				)}
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

			{/* Create version modal */}
			{showCreateVersionModal && (
				<CreateVersionModal
					show={showCreateVersionModal}
					onClose={() => setShowCreateVersionModal(false)}
					onCreate={handleCreateVersion}
					projectId={projectId}
				/>
			)}

			{/* Batch upload modal */}
			{showBatchUploadModal && (
				<BatchUploadModal
					projectId={projectId}
					onClose={() => setShowBatchUploadModal(false)}
					onUploadComplete={handleBatchUploadComplete}
				/>
			)}
		</div>
	);
};

export default ProjectPage;
