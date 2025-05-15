import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import {
	Container,
	Title,
	Button,
	Group,
	Text,
	Paper,
	Divider,
	Tabs,
	Badge,
	Modal,
	Alert,
	Loader,
} from '@mantine/core';
import {
	FiEdit,
	FiTrash2,
	FiPlus,
	FiUsers,
	FiMusic,
	FiAlertCircle,
	FiFolder,
} from 'react-icons/fi';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/api';

const ProjectPage = () => {
	const { workspaceId, projectId } = useParams();
	const navigate = useNavigate();
	const { currentUser } = useAuth();

	const [project, setProject] = useState(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [isOwner, setIsOwner] = useState(false);

	// Modal states
	const [newVersionModalOpen, setNewVersionModalOpen] = useState(false);
	const [inviteModalOpen, setInviteModalOpen] = useState(false);
	const [deleteModalOpen, setDeleteModalOpen] = useState(false);

	useEffect(() => {
		const fetchProject = async () => {
			try {
				setLoading(true);

				// In a real implementation, this would be an actual API call
				// For now, we'll create dummy data
				const projectData = {
					id: parseInt(projectId),
					title: 'Summer EP',
					description: 'Four-track summer vibes EP',
					workspace_id: parseInt(workspaceId),
					user_id: 1, // Assuming this matches currentUser.id
					created_at: '2023-01-15T12:00:00Z',
					visibility: 'private',
					track_versions: [
						{
							id: 1,
							title: 'Initial Demo',
							created_at: '2023-01-16T10:30:00Z',
							user_id: 1,
							username: 'producer1',
						},
						{
							id: 2,
							title: 'Added Vocals',
							created_at: '2023-01-18T14:45:00Z',
							user_id: 2,
							username: 'vocalist',
						},
						{
							id: 3,
							title: 'Mix v1',
							created_at: '2023-01-20T09:15:00Z',
							user_id: 1,
							username: 'producer1',
						},
					],
					collaborators: [
						{ id: 1, username: 'producer1', role: 'owner' },
						{ id: 2, username: 'vocalist', role: 'collaborator' },
					],
				};

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

	const handleDeleteVersion = async (versionId) => {
		if (window.confirm('Are you sure you want to delete this version?')) {
			try {
				// Mock API call for version deletion
				console.log(`Deleting version ${versionId}`);

				// Update state to remove the deleted version
				setProject((prev) => ({
					...prev,
					track_versions: prev.track_versions.filter((v) => v.id !== versionId),
				}));
			} catch (err) {
				console.error('Error deleting version:', err);
				alert('Failed to delete version. Please try again.');
			}
		}
	};

	const handleDeleteProject = async () => {
		try {
			// Mock API call for project deletion
			console.log(`Deleting project ${projectId}`);
			navigate(`/workspaces/${workspaceId}`);
		} catch (err) {
			console.error('Error deleting project:', err);
			alert('Failed to delete project. Please try again.');
		}
	};

	if (loading) {
		return (
			<Container
				size='xl'
				style={{ display: 'flex', justifyContent: 'center', padding: '40px 0' }}
			>
				<Loader size='lg' />
			</Container>
		);
	}

	if (error) {
		return (
			<Container
				size='xl'
				py='xl'
			>
				<Alert
					icon={<FiAlertCircle size={16} />}
					title='Error'
					color='red'
				>
					{error}
				</Alert>
			</Container>
		);
	}

	if (!project) {
		return (
			<Container
				size='xl'
				py='xl'
			>
				<Alert
					icon={<FiAlertCircle size={16} />}
					title='Project Not Found'
					color='yellow'
				>
					The project you are looking for does not exist or you do not have
					permission to view it.
				</Alert>
			</Container>
		);
	}

	return (
		<Container size='xl'>
			<Paper
				p='md'
				withBorder
				mb='xl'
			>
				<Group
					position='apart'
					mb='xs'
				>
					<div>
						<Title order={2}>{project.title}</Title>
						<Group spacing='xs'>
							<Badge color={project.visibility === 'public' ? 'blue' : 'gray'}>
								{project.visibility}
							</Badge>
							<Text
								size='sm'
								color='dimmed'
							>
								Created: {new Date(project.created_at).toLocaleDateString()}
							</Text>
						</Group>
					</div>

					{isOwner && (
						<Group>
							<Button
								component={Link}
								to={`/workspaces/${workspaceId}/projects/${projectId}/edit`}
								variant='outline'
								leftIcon={<FiEdit size={16} />}
							>
								Edit Project
							</Button>
							<Button
								color='red'
								variant='outline'
								leftIcon={<FiTrash2 size={16} />}
								onClick={() => setDeleteModalOpen(true)}
							>
								Delete
							</Button>
						</Group>
					)}
				</Group>

				{project.description && (
					<>
						<Divider my='sm' />
						<Text>{project.description}</Text>
					</>
				)}
			</Paper>

			<Tabs defaultValue='versions'>
				<Tabs.List mb='md'>
					<Tabs.Tab
						value='versions'
						icon={<FiMusic size={14} />}
					>
						Versions
					</Tabs.Tab>
					<Tabs.Tab
						value='collaborators'
						icon={<FiUsers size={14} />}
					>
						Collaborators
					</Tabs.Tab>
				</Tabs.List>

				<Tabs.Panel
					value='versions'
					pt='xs'
				>
					<Group
						position='right'
						mb='md'
					>
						<Button
							leftIcon={<FiPlus size={16} />}
							onClick={() => setNewVersionModalOpen(true)}
						>
							New Version
						</Button>
					</Group>

					<Paper
						withBorder
						p='md'
					>
						<Table striped>
							<thead>
								<tr>
									<th>Version</th>
									<th>Created By</th>
									<th>Date</th>
									<th>Actions</th>
								</tr>
							</thead>
							<tbody>
								{project.track_versions.map((version) => (
									<tr key={version.id}>
										<td>
											<Link
												to={`/projects/${projectId}/versions/${version.id}`}
												style={{ textDecoration: 'none' }}
											>
												<Text weight={500}>{version.title}</Text>
											</Link>
										</td>
										<td>{version.username}</td>
										<td>{new Date(version.created_at).toLocaleString()}</td>
										<td>
											<Group spacing='xs'>
												<Button
													compact
													variant='subtle'
													component={Link}
													to={`/projects/${projectId}/versions/${version.id}`}
												>
													View
												</Button>
												{(isOwner || version.user_id === currentUser?.id) && (
													<Button
														compact
														variant='subtle'
														color='red'
														onClick={() => handleDeleteVersion(version.id)}
													>
														Delete
													</Button>
												)}
											</Group>
										</td>
									</tr>
								))}
							</tbody>
						</Table>
					</Paper>
				</Tabs.Panel>

				<Tabs.Panel
					value='collaborators'
					pt='xs'
				>
					{isOwner && (
						<Group
							position='right'
							mb='md'
						>
							<Button
								leftIcon={<FiPlus size={16} />}
								onClick={() => setInviteModalOpen(true)}
							>
								Invite Collaborator
							</Button>
						</Group>
					)}

					<Paper
						withBorder
						p='md'
					>
						<Table>
							<thead>
								<tr>
									<th>User</th>
									<th>Role</th>
									{isOwner && <th>Actions</th>}
								</tr>
							</thead>
							<tbody>
								{project.collaborators.map((collaborator) => (
									<tr key={collaborator.id}>
										<td>
											<Group>
												<Avatar
													size='sm'
													radius='xl'
												/>
												<Text>{collaborator.username}</Text>
											</Group>
										</td>
										<td>
											<Badge
												color={collaborator.role === 'owner' ? 'blue' : 'green'}
											>
												{collaborator.role}
											</Badge>
										</td>
										{isOwner && collaborator.role !== 'owner' && (
											<td>
												<Button
													compact
													variant='subtle'
													color='red'
												>
													Remove
												</Button>
											</td>
										)}
										{isOwner && collaborator.role === 'owner' && <td></td>}
									</tr>
								))}
							</tbody>
						</Table>
					</Paper>
				</Tabs.Panel>
			</Tabs>

			{/* Delete Project Modal */}
			<Modal
				opened={deleteModalOpen}
				onClose={() => setDeleteModalOpen(false)}
				title='Delete Project'
			>
				<Text mb='lg'>
					Are you sure you want to delete this project? This action cannot be
					undone and all versions and collaborator data will be permanently
					lost.
				</Text>
				<Group position='right'>
					<Button
						variant='default'
						onClick={() => setDeleteModalOpen(false)}
					>
						Cancel
					</Button>
					<Button
						color='red'
						onClick={handleDeleteProject}
					>
						Delete Project
					</Button>
				</Group>
			</Modal>

			{/* New Version Modal */}
			<Modal
				opened={newVersionModalOpen}
				onClose={() => setNewVersionModalOpen(false)}
				title='Add New Version'
				size='lg'
			>
				<Text mb='lg'>This will contain the new version form</Text>
				<Group position='right'>
					<Button onClick={() => setNewVersionModalOpen(false)}>Cancel</Button>
				</Group>
			</Modal>

			{/* Invite Collaborator Modal */}
			<Modal
				opened={inviteModalOpen}
				onClose={() => setInviteModalOpen(false)}
				title='Invite Collaborator'
			>
				<Text mb='lg'>This will contain the invite form</Text>
				<Group position='right'>
					<Button onClick={() => setInviteModalOpen(false)}>Cancel</Button>
				</Group>
			</Modal>
		</Container>
	);
};

// Import necessary components for the tables
const Table = ({ children, striped }) => (
	<table style={{ width: '100%', borderCollapse: 'collapse' }}>
		{children}
	</table>
);

const Avatar = ({ size, radius }) => (
	<div
		style={{
			width: size === 'sm' ? '30px' : '40px',
			height: size === 'sm' ? '30px' : '40px',
			borderRadius: radius === 'xl' ? '50%' : '4px',
			backgroundColor: '#e0e0e0',
			display: 'inline-block',
		}}
	/>
);

export default ProjectPage;
