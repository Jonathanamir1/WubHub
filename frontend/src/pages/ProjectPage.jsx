// frontend/src/pages/ProjectPage.jsx
import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate, useLocation } from 'react-router-dom';
import {
	FiEdit,
	FiTrash2,
	FiPlus,
	FiUsers,
	FiMusic,
	FiAlertCircle,
	FiFileText,
	FiFile,
	FiImage,
	FiHardDrive,
	FiUpload,
	FiDownload,
	FiChevronLeft,
	FiSettings,
	FiCalendar,
	FiClock,
	FiTag,
	FiEye,
	FiEyeOff,
	FiHeart,
	FiShare2,
	FiStar,
} from 'react-icons/fi';
import api from '../services/api';
import { useAuth } from '../contexts/AuthContext';
import VersionsList from '../components/projects/VersionsList';
import ProjectHeader from '../components/projects/ProjectHeader';
import CollaboratorsList from '../components/projects/CollaboratorsList';
import FileUploadModal from '../components/projects/FileUploadModal';
import DeleteConfirmModal from '../components/common/DeleteConfirmModal';
import CreateVersionModal from '../components/projects/CreateVersionModal';
import ProjectSidebar from '../components/projects/ProjectSidebar';
import EmptyState from '../components/common/EmptyState';
import ContentSection from '../components/projects/ContentSection';

const ProjectPage = () => {
	const { workspaceId, projectId } = useParams();
	const navigate = useNavigate();
	const location = useLocation();
	const { currentUser } = useAuth();

	// State variables
	const [project, setProject] = useState(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [activeTab, setActiveTab] = useState('overview');
	const [isOwner, setIsOwner] = useState(false);
	const [collaborators, setCollaborators] = useState([]);
	const [versions, setVersions] = useState([]);
	const [selectedVersion, setSelectedVersion] = useState(null);
	const [contentSections, setContentSections] = useState({
		documents: [],
		audio: [],
		images: [],
		projects: [],
	});

	// Modal states
	const [showUploadModal, setShowUploadModal] = useState(false);
	const [showDeleteProjectModal, setShowDeleteProjectModal] = useState(false);
	const [showCreateVersionModal, setShowCreateVersionModal] = useState(false);
	const [uploadType, setUploadType] = useState(null);

	// Fetch project data
	useEffect(() => {
		const fetchProject = async () => {
			try {
				setLoading(true);
				const response = await api.getProject(workspaceId, projectId);
				const projectData = response.data;

				setProject(projectData);
				setIsOwner(projectData.user_id === currentUser?.id);

				// Set active tab based on project type
				setActiveTab(projectData.project_type || 'overview');

				// Fetch project versions
				fetchVersions(projectId);

				// Fetch collaborators
				fetchCollaborators(projectId);

				setError(null);
			} catch (err) {
				console.error('Error fetching project:', err);
				setError('Failed to load project. Please try again later.');

				// Fallback to mock data for development
				useMockProjectData();
			} finally {
				setLoading(false);
			}
		};

		fetchProject();
	}, [projectId, workspaceId, currentUser?.id]);

	const fetchVersions = async (projId) => {
		try {
			const response = await api.getTrackVersions(projId);
			setVersions(response.data || []);

			// Set the latest version as selected by default
			if (response.data && response.data.length > 0) {
				setSelectedVersion(response.data[0]);
			}
		} catch (err) {
			console.error('Error fetching versions:', err);
			// Use mock versions data for development
			const mockVersions = [
				{
					id: 1,
					title: 'Initial Demo',
					created_at: '2023-04-16T10:30:00Z',
					user_id: 1,
					username: 'producer1',
				},
				{
					id: 2,
					title: 'Added Vocals',
					created_at: '2023-04-18T14:45:00Z',
					user_id: 2,
					username: 'vocalist',
				},
				{
					id: 3,
					title: 'Mix v1',
					created_at: '2023-04-20T09:15:00Z',
					user_id: 1,
					username: 'producer1',
				},
			];
			setVersions(mockVersions);
			setSelectedVersion(mockVersions[0]);
		}
	};

	const fetchCollaborators = async (projId) => {
		try {
			// In a real implementation, this would be an actual API call
			// For now, using mock data
			const mockCollaborators = [
				{
					id: 1,
					username: 'producer1',
					name: 'Pro Producer',
					role: 'owner',
					avatar: null,
				},
				{
					id: 2,
					username: 'vocalist',
					name: 'Vocal Artist',
					role: 'collaborator',
					avatar: null,
				},
				{
					id: 3,
					username: 'songwriter',
					name: 'Song Writer',
					role: 'viewer',
					avatar: null,
				},
			];
			setCollaborators(mockCollaborators);
		} catch (err) {
			console.error('Error fetching collaborators:', err);
		}
	};

	const useMockProjectData = () => {
		const mockProject = {
			id: parseInt(projectId),
			title: 'Summer EP',
			description: 'Four-track summer vibes EP',
			workspace_id: parseInt(workspaceId),
			user_id: currentUser?.id || 1, // Simulate ownership
			created_at: '2023-04-15T12:00:00Z',
			updated_at: '2023-04-25T14:30:00Z',
			visibility: 'private',
			project_type: 'production',
		};

		setProject(mockProject);
		setIsOwner(mockProject.user_id === currentUser?.id);
		setActiveTab(mockProject.project_type || 'overview');

		// Set mock content sections based on project type
		const mockContentSections = generateMockContentSections(
			mockProject.project_type
		);
		setContentSections(mockContentSections);
	};

	const generateMockContentSections = (projectType) => {
		// Generate different mock content based on project type
		switch (projectType) {
			case 'songwriting':
				return {
					documents: [
						{
							id: 1,
							name: 'Lyrics - Verse 1',
							type: 'document',
							created_at: '2023-04-16T10:00:00Z',
						},
						{
							id: 2,
							name: 'Chord progression',
							type: 'document',
							created_at: '2023-04-17T11:30:00Z',
						},
					],
					audio: [
						{
							id: 1,
							name: 'Voice Memo - Chorus Idea',
							type: 'audio',
							created_at: '2023-04-18T09:45:00Z',
						},
					],
					images: [],
					projects: [],
				};

			case 'production':
				return {
					documents: [
						{
							id: 1,
							name: 'Production Notes',
							type: 'document',
							created_at: '2023-04-16T10:00:00Z',
						},
					],
					audio: [
						{
							id: 1,
							name: 'Beat Draft',
							type: 'audio',
							created_at: '2023-04-16T14:20:00Z',
						},
						{
							id: 2,
							name: 'Vocal Take 1',
							type: 'audio',
							created_at: '2023-04-17T15:30:00Z',
						},
						{
							id: 3,
							name: 'Vocal Take 2',
							type: 'audio',
							created_at: '2023-04-18T10:15:00Z',
						},
					],
					images: [],
					projects: [
						{
							id: 1,
							name: 'Project File v1',
							type: 'project',
							created_at: '2023-04-18T16:45:00Z',
						},
					],
				};

			case 'mixing':
				return {
					documents: [
						{
							id: 1,
							name: 'Mix Notes',
							type: 'document',
							created_at: '2023-04-19T11:20:00Z',
						},
					],
					audio: [
						{
							id: 1,
							name: 'Mix v1',
							type: 'audio',
							created_at: '2023-04-20T13:10:00Z',
						},
						{
							id: 2,
							name: 'Mix v2 - Revised Vocals',
							type: 'audio',
							created_at: '2023-04-21T09:30:00Z',
						},
					],
					images: [],
					projects: [
						{
							id: 1,
							name: 'Mix Session',
							type: 'project',
							created_at: '2023-04-20T13:15:00Z',
						},
					],
				};

			case 'mastering':
				return {
					documents: [
						{
							id: 1,
							name: 'Mastering Notes',
							type: 'document',
							created_at: '2023-04-22T10:00:00Z',
						},
					],
					audio: [
						{
							id: 1,
							name: 'Mastered Track v1',
							type: 'audio',
							created_at: '2023-04-23T14:20:00Z',
						},
						{
							id: 2,
							name: 'Mastered Track - Streaming',
							type: 'audio',
							created_at: '2023-04-23T14:25:00Z',
						},
						{
							id: 3,
							name: 'Mastered Track - CD',
							type: 'audio',
							created_at: '2023-04-23T14:30:00Z',
						},
					],
					images: [],
					projects: [],
				};

			default:
				return {
					documents: [],
					audio: [],
					images: [],
					projects: [],
				};
		}
	};

	const handleDeleteProject = async () => {
		try {
			await api.deleteProject(workspaceId, projectId);
			navigate(`/workspaces/${workspaceId}`);
		} catch (err) {
			console.error('Error deleting project:', err);
			alert('Failed to delete project. Please try again.');
		}
	};

	const handleCreateVersion = async (versionData) => {
		try {
			const response = await api.createTrackVersion(projectId, versionData);
			setVersions([response.data, ...versions]);
			setSelectedVersion(response.data);
			setShowCreateVersionModal(false);
		} catch (err) {
			console.error('Error creating version:', err);
			alert('Failed to create version. Please try again.');
		}
	};

	const handleDeleteVersion = async (versionId) => {
		if (window.confirm('Are you sure you want to delete this version?')) {
			try {
				await api.deleteTrackVersion(projectId, versionId);
				const updatedVersions = versions.filter((v) => v.id !== versionId);
				setVersions(updatedVersions);

				// Update selected version if the deleted one was selected
				if (selectedVersion?.id === versionId) {
					setSelectedVersion(
						updatedVersions.length > 0 ? updatedVersions[0] : null
					);
				}
			} catch (err) {
				console.error('Error deleting version:', err);
				alert('Failed to delete version. Please try again.');
			}
		}
	};

	const handleOpenUploadModal = (type) => {
		setUploadType(type);
		setShowUploadModal(true);
	};

	const handleUpload = async (file, metadata) => {
		// In a real implementation, this would call an API to upload the file
		console.log('Uploading file:', file, 'with metadata:', metadata);

		// Mock implementation - add the file to the appropriate content section
		const newFile = {
			id: Date.now(), // Generate a temporary ID
			name: file.name,
			type: uploadType,
			created_at: new Date().toISOString(),
			// Add additional metadata as needed
			size: file.size,
			...metadata,
		};

		// Update the content sections based on file type
		setContentSections((prev) => {
			const section =
				uploadType === 'document'
					? 'documents'
					: uploadType === 'audio'
					? 'audio'
					: uploadType === 'image'
					? 'images'
					: 'projects';

			return {
				...prev,
				[section]: [newFile, ...prev[section]],
			};
		});

		setShowUploadModal(false);
	};

	if (loading) {
		return (
			<div className='flex justify-center items-center h-64'>
				<div className='animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-ableton-blue-500'></div>
			</div>
		);
	}

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
		<div className='flex flex-col md:flex-row'>
			{/* Left sidebar - only shown on non-mobile */}
			<div className='hidden md:block w-64 bg-ableton-dark-300 border-r border-ableton-dark-200 h-screen fixed left-0 top-16 pt-6 px-4 overflow-y-auto'>
				<ProjectSidebar
					project={project}
					activeTab={activeTab}
					setActiveTab={setActiveTab}
					versions={versions}
					selectedVersion={selectedVersion}
					setSelectedVersion={setSelectedVersion}
					collaborators={collaborators}
					isOwner={isOwner}
					onCreateVersion={() => setShowCreateVersionModal(true)}
				/>
			</div>

			{/* Main content */}
			<div className='md:ml-64 w-full'>
				<div className='px-4 py-6'>
					{/* Mobile navigation - only shown on mobile */}
					<div className='block md:hidden mb-4'>
						<button
							onClick={() => navigate(`/workspaces/${workspaceId}`)}
							className='flex items-center text-gray-400 hover:text-white mb-2'
						>
							<FiChevronLeft className='w-4 h-4 mr-1' /> Back to Workspace
						</button>

						<select
							value={activeTab}
							onChange={(e) => setActiveTab(e.target.value)}
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-2 text-white'
						>
							<option value='overview'>Overview</option>
							<option value='songwriting'>Songwriting</option>
							<option value='production'>Production</option>
							<option value='mixing'>Mixing</option>
							<option value='mastering'>Mastering</option>
							<option value='versions'>Versions</option>
							<option value='collaborators'>Collaborators</option>
							<option value='settings'>Settings</option>
						</select>
					</div>

					{/* Project header */}
					<ProjectHeader
						project={project}
						isOwner={isOwner}
						onEdit={() =>
							navigate(`/workspaces/${workspaceId}/projects/${projectId}/edit`)
						}
						onDelete={() => setShowDeleteProjectModal(true)}
					/>

					{/* Main content based on active tab */}
					<div className='mt-6'>
						{activeTab === 'overview' && (
							<div className='grid grid-cols-1 md:grid-cols-2 gap-6'>
								<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200'>
									<h3 className='text-lg font-medium mb-3 flex items-center'>
										<FiMusic className='mr-2' /> Latest Versions
									</h3>
									{versions.length > 0 ? (
										<div className='space-y-2'>
											{versions.slice(0, 3).map((version) => (
												<div
													key={version.id}
													className='p-3 bg-ableton-dark-200 rounded-md hover:bg-ableton-dark-100 transition-colors flex justify-between'
												>
													<div>
														<h4 className='font-medium'>{version.title}</h4>
														<p className='text-sm text-gray-400'>
															By {version.username} •{' '}
															{new Date(
																version.created_at
															).toLocaleDateString()}
														</p>
													</div>
													<button
														onClick={() =>
															navigate(
																`/projects/${projectId}/versions/${version.id}`
															)
														}
														className='text-ableton-blue-400 hover:text-ableton-blue-300'
													>
														View
													</button>
												</div>
											))}
										</div>
									) : (
										<EmptyState
											icon={<FiMusic className='w-8 h-8' />}
											title='No versions yet'
											message='Create your first version to start tracking your progress'
											actionText='Create Version'
											onAction={() => setShowCreateVersionModal(true)}
										/>
									)}
									{versions.length > 0 && (
										<button
											onClick={() => setActiveTab('versions')}
											className='mt-3 text-sm text-ableton-blue-400 hover:text-ableton-blue-300'
										>
											View all versions →
										</button>
									)}
								</div>

								<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200'>
									<h3 className='text-lg font-medium mb-3 flex items-center'>
										<FiUsers className='mr-2' /> Collaborators
									</h3>
									{collaborators.length > 0 ? (
										<div className='space-y-2'>
											{collaborators.map((collaborator) => (
												<div
													key={collaborator.id}
													className='p-3 bg-ableton-dark-200 rounded-md hover:bg-ableton-dark-100 transition-colors flex justify-between items-center'
												>
													<div className='flex items-center'>
														<div className='w-8 h-8 rounded-full bg-ableton-blue-500 flex items-center justify-center text-white font-medium mr-3'>
															{collaborator.username
																?.charAt(0)
																?.toUpperCase() || 'U'}
														</div>
														<div>
															<h4 className='font-medium'>
																{collaborator.name || collaborator.username}
															</h4>
															<p className='text-sm text-gray-400'>
																{collaborator.role}
															</p>
														</div>
													</div>
												</div>
											))}
										</div>
									) : (
										<EmptyState
											icon={<FiUsers className='w-8 h-8' />}
											title='No collaborators yet'
											message='Invite others to collaborate on this project'
											actionText='Invite Collaborators'
											onAction={() => setActiveTab('collaborators')}
											showAction={isOwner}
										/>
									)}
									{collaborators.length > 0 && (
										<button
											onClick={() => setActiveTab('collaborators')}
											className='mt-3 text-sm text-ableton-blue-400 hover:text-ableton-blue-300'
										>
											View all collaborators →
										</button>
									)}
								</div>

								<div className='bg-ableton-dark-300 rounded-md p-4 border border-ableton-dark-200 md:col-span-2'>
									<h3 className='text-lg font-medium mb-3 flex items-center'>
										<FiCalendar className='mr-2' /> Project Activity
									</h3>
									<p className='text-gray-400'>
										Recent activity will be shown here. For now, you can explore
										the different sections of your project.
									</p>
								</div>
							</div>
						)}

						{activeTab === 'songwriting' && (
							<div className='space-y-6'>
								<ContentSection
									title='Lyrics & Documents'
									icon={<FiFileText />}
									items={contentSections.documents}
									emptyMessage='Upload lyrics, chord charts, or other songwriting documents'
									onUpload={() => handleOpenUploadModal('document')}
								/>

								<ContentSection
									title='Voice Memos & Demos'
									icon={<FiMusic />}
									items={contentSections.audio}
									emptyMessage='Upload voice memos, rough recordings, or demo tracks'
									onUpload={() => handleOpenUploadModal('audio')}
								/>

								<ContentSection
									title='Images & References'
									icon={<FiImage />}
									items={contentSections.images}
									emptyMessage='Upload images for inspiration or reference'
									onUpload={() => handleOpenUploadModal('image')}
								/>
							</div>
						)}

						{activeTab === 'production' && (
							<div className='space-y-6'>
								<ContentSection
									title='DAW Projects'
									icon={<FiHardDrive />}
									items={contentSections.projects}
									emptyMessage='Upload your DAW project files (Ableton, Logic, etc.)'
									onUpload={() => handleOpenUploadModal('project')}
								/>

								<ContentSection
									title='Audio Files'
									icon={<FiMusic />}
									items={contentSections.audio}
									emptyMessage='Upload audio stems, bounces, or rendered tracks'
									onUpload={() => handleOpenUploadModal('audio')}
								/>

								<ContentSection
									title='Production Notes'
									icon={<FiFileText />}
									items={contentSections.documents}
									emptyMessage='Upload notes about your production decisions'
									onUpload={() => handleOpenUploadModal('document')}
								/>
							</div>
						)}

						{activeTab === 'mixing' && (
							<div className='space-y-6'>
								<ContentSection
									title='Mix Sessions'
									icon={<FiHardDrive />}
									items={contentSections.projects}
									emptyMessage='Upload your mixing session files'
									onUpload={() => handleOpenUploadModal('project')}
								/>

								<ContentSection
									title='Mix Versions'
									icon={<FiMusic />}
									items={contentSections.audio}
									emptyMessage='Upload different mix versions for comparison'
									onUpload={() => handleOpenUploadModal('audio')}
								/>

								<ContentSection
									title='Mix Notes'
									icon={<FiFileText />}
									items={contentSections.documents}
									emptyMessage='Upload mix notes and feedback'
									onUpload={() => handleOpenUploadModal('document')}
								/>
							</div>
						)}

						{activeTab === 'mastering' && (
							<div className='space-y-6'>
								<ContentSection
									title='Mastered Tracks'
									icon={<FiMusic />}
									items={contentSections.audio}
									emptyMessage='Upload mastered audio files for different formats'
									onUpload={() => handleOpenUploadModal('audio')}
								/>

								<ContentSection
									title='Mastering Notes'
									icon={<FiFileText />}
									items={contentSections.documents}
									emptyMessage='Upload notes about mastering decisions and settings'
									onUpload={() => handleOpenUploadModal('document')}
								/>

								<ContentSection
									title='Reference Tracks'
									icon={<FiMusic />}
									items={[]}
									emptyMessage='Upload reference tracks for comparison'
									onUpload={() => handleOpenUploadModal('audio')}
								/>
							</div>
						)}

						{activeTab === 'versions' && (
							<VersionsList
								versions={versions}
								selectedVersion={selectedVersion}
								setSelectedVersion={setSelectedVersion}
								projectId={projectId}
								isOwner={isOwner}
								currentUserId={currentUser?.id}
								onCreateVersion={() => setShowCreateVersionModal(true)}
								onDeleteVersion={handleDeleteVersion}
							/>
						)}

						{activeTab === 'collaborators' && (
							<CollaboratorsList
								collaborators={collaborators}
								isOwner={isOwner}
								onInvite={() => console.log('Open invite modal')}
							/>
						)}

						{activeTab === 'settings' && isOwner && (
							<div className='bg-ableton-dark-300 rounded-md border border-ableton-dark-200 overflow-hidden'>
								<div className='p-4 border-b border-ableton-dark-200'>
									<h3 className='text-lg font-medium'>Project Settings</h3>
								</div>

								<div className='p-4'>
									<div className='space-y-4'>
										<div>
											<label className='block text-sm text-gray-400 mb-1'>
												Project Type
											</label>
											<select
												className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white'
												value={project.project_type}
												disabled
											>
												<option value='production'>Production</option>
												<option value='songwriting'>Songwriting</option>
												<option value='mixing'>Mixing</option>
												<option value='mastering'>Mastering</option>
												<option value='other'>Other</option>
											</select>
											<p className='mt-1 text-sm text-gray-500'>
												Project type cannot be changed after creation
											</p>
										</div>

										<div>
											<label className='block text-sm text-gray-400 mb-1'>
												Visibility
											</label>
											<select
												className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white'
												value={project.visibility}
												disabled
											>
												<option value='private'>Private</option>
												<option value='public'>Public</option>
											</select>
										</div>

										<div className='pt-4 border-t border-ableton-dark-200'>
											<button
												onClick={() => setShowDeleteProjectModal(true)}
												className='px-4 py-2 bg-red-500/20 text-red-400 hover:bg-red-500/30 rounded-md transition-colors flex items-center'
											>
												<FiTrash2 className='mr-2' /> Delete Project
											</button>
											<p className='mt-1 text-sm text-gray-500'>
												This action cannot be undone
											</p>
										</div>
									</div>
								</div>
							</div>
						)}
					</div>
				</div>
			</div>

			{/* Modals */}
			{showUploadModal && (
				<FileUploadModal
					show={showUploadModal}
					onClose={() => setShowUploadModal(false)}
					onUpload={handleUpload}
					uploadType={uploadType}
					versionId={selectedVersion?.id}
				/>
			)}

			{showDeleteProjectModal && (
				<DeleteConfirmModal
					show={showDeleteProjectModal}
					onClose={() => setShowDeleteProjectModal(false)}
					onConfirm={handleDeleteProject}
					title='Delete Project'
					message='Are you sure you want to delete this project? This action cannot be undone and all versions, files, and data will be permanently lost.'
					confirmText='Delete Project'
				/>
			)}

			{showCreateVersionModal && (
				<CreateVersionModal
					show={showCreateVersionModal}
					onClose={() => setShowCreateVersionModal(false)}
					onCreate={handleCreateVersion}
					projectId={projectId}
				/>
			)}
		</div>
	);
};

export default ProjectPage;
