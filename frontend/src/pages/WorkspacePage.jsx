import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import {
	Container,
	Title,
	Button,
	Group,
	Text,
	Paper,
	Grid,
	Card,
	Badge,
	Loader,
	Alert,
	Tabs,
	Avatar,
	Table,
} from '@mantine/core';
import { FiPlus, FiUsers, FiSettings, FiAlertCircle } from 'react-icons/fi';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/api';

const WorkspacePage = () => {
	const { workspaceId } = useParams();
	const { currentUser } = useAuth();

	const [workspace, setWorkspace] = useState(null);
	const [projects, setProjects] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);

	useEffect(() => {
		const fetchWorkspace = async () => {
			try {
				setLoading(true);

				// In a real implementation, this would be an actual API call
				// For now, we'll create dummy data
				const workspaceData = {
					id: parseInt(workspaceId),
					name: 'Music Production',
					description: 'Main workspace for production projects',
					workspace_type: 'production',
					user_id: 1,
					created_at: '2023-01-15T12:00:00Z',
					members: [
						{ id: 1, username: 'producer1', role: 'owner' },
						{ id: 2, username: 'vocalist', role: 'member' },
						{ id: 3, username: 'songwriter', role: 'member' },
					],
				};

				const projectsData = [
					{
						id: 1,
						title: 'Summer EP',
						description: 'Four-track summer vibes EP',
						version_count: 12,
						updated_at: '2023-05-12T10:15:00Z',
					},
					{
						id: 2,
						title: 'Client Mix - Jane Doe',
						description: "Mixing project for Jane's album",
						version_count: 8,
						updated_at: '2023-05-10T16:45:00Z',
					},
				];

				setWorkspace(workspaceData);
				setProjects(projectsData);
				setError(null);
			} catch (err) {
				console.error('Error fetching workspace:', err);
				setError('Failed to load workspace. Please try again later.');
			} finally {
				setLoading(false);
			}
		};

		fetchWorkspace();
	}, [workspaceId]);

	if (loading) {
		return (
			<Container
				size='xl'
				py='xl'
				style={{ display: 'flex', justifyContent: 'center' }}
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

	if (!workspace) {
		return (
			<Container
				size='xl'
				py='xl'
			>
				<Alert
					icon={<FiAlertCircle size={16} />}
					title='Not Found'
					color='yellow'
				>
					Workspace not found or you don't have access to it.
				</Alert>
			</Container>
		);
	}

	const isOwner = workspace.user_id === currentUser?.id;

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
						<Title order={2}>{workspace.name}</Title>
						<Badge
							color='blue'
							mb='sm'
						>
							{workspace.workspace_type}
						</Badge>
						{workspace.description && <Text>{workspace.description}</Text>}
					</div>

					{isOwner && (
						<Button
							component={Link}
							to={`/workspaces/${workspaceId}/settings`}
							variant='outline'
							leftIcon={<FiSettings size={16} />}
						>
							Workspace Settings
						</Button>
					)}
				</Group>
			</Paper>

			<Tabs defaultValue='projects'>
				<Tabs.List mb='md'>
					<Tabs.Tab
						value='projects'
						icon={<FiAlertCircle size={14} />}
					>
						Projects
					</Tabs.Tab>
					<Tabs.Tab
						value='members'
						icon={<FiUsers size={14} />}
					>
						Members
					</Tabs.Tab>
				</Tabs.List>

				<Tabs.Panel
					value='projects'
					pt='xs'
				>
					<Group
						position='right'
						mb='md'
					>
						<Button
							component={Link}
							to={`/workspaces/${workspaceId}/projects/new`}
							leftIcon={<FiPlus size={16} />}
						>
							New Project
						</Button>
					</Group>

					<Grid>
						{projects.map((project) => (
							<Grid.Col
								key={project.id}
								xs={12}
								sm={6}
								lg={4}
							>
								<Card
									shadow='sm'
									p='lg'
									radius='md'
									withBorder
								>
									<Group
										position='apart'
										mb='xs'
									>
										<Text weight={500}>{project.title}</Text>
										<Badge>{project.version_count} versions</Badge>
									</Group>

									<Text
										size='sm'
										color='dimmed'
										mb='md'
									>
										{project.description}
									</Text>

									<Text
										size='xs'
										color='dimmed'
										mb='md'
									>
										Last updated:{' '}
										{new Date(project.updated_at).toLocaleDateString()}
									</Text>

									<Button
										component={Link}
										to={`/workspaces/${workspaceId}/projects/${project.id}`}
										variant='light'
										color='blue'
										fullWidth
										mt='md'
										radius='md'
									>
										Open Project
									</Button>
								</Card>
							</Grid.Col>
						))}
					</Grid>
				</Tabs.Panel>

				<Tabs.Panel
					value='members'
					pt='xs'
				>
					<Group
						position='right'
						mb='md'
					>
						{isOwner && (
							<Button leftIcon={<FiPlus size={16} />}>Invite Member</Button>
						)}
					</Group>

					<Paper
						withBorder
						p='md'
					>
						<Table>
							<thead>
								<tr>
									<th>Member</th>
									<th>Role</th>
									{isOwner && <th>Actions</th>}
								</tr>
							</thead>
							<tbody>
								{workspace.members.map((member) => (
									<tr key={member.id}>
										<td>
											<Group>
												<Avatar
													size='sm'
													radius='xl'
												/>
												<Text>{member.username}</Text>
											</Group>
										</td>
										<td>
											<Badge color={member.role === 'owner' ? 'blue' : 'green'}>
												{member.role}
											</Badge>
										</td>
										{isOwner && member.role !== 'owner' && (
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
										{isOwner && member.role === 'owner' && <td></td>}
									</tr>
								))}
							</tbody>
						</Table>
					</Paper>
				</Tabs.Panel>
			</Tabs>
		</Container>
	);
};

export default WorkspacePage;
