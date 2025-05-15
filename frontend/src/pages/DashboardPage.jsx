import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
	Container,
	Title,
	Grid,
	Button,
	Text,
	Group,
	Tabs,
	Loader,
	Alert,
	Card,
	Badge,
	Image,
} from '@mantine/core';
import { FiPlus, FiAlertCircle, FiGrid, FiArchive } from 'react-icons/fi';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/api';

const DashboardPage = () => {
	const { currentUser } = useAuth();
	const [workspaces, setWorkspaces] = useState([]);
	const [recentProjects, setRecentProjects] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);

	useEffect(() => {
		const fetchData = async () => {
			try {
				setLoading(true);

				// In a real implementation, these would be actual API calls
				// For now, we'll create dummy data
				const workspaceData = [
					{
						id: 1,
						name: 'Music Production',
						description: 'Main workspace for production projects',
						workspace_type: 'production',
						project_count: 5,
						created_at: '2023-01-15T12:00:00Z',
					},
					{
						id: 2,
						name: 'Songwriting',
						description: 'Collaborative songwriting space',
						workspace_type: 'songwriting',
						project_count: 3,
						created_at: '2023-02-10T14:30:00Z',
					},
				];

				const projectData = [
					{
						id: 1,
						title: 'Summer EP',
						description: 'Four-track summer vibes EP',
						workspace_id: 1,
						version_count: 12,
						updated_at: '2023-05-12T10:15:00Z',
					},
					{
						id: 2,
						title: 'Client Mix - Jane Doe',
						description: "Mixing project for Jane's album",
						workspace_id: 1,
						version_count: 8,
						updated_at: '2023-05-10T16:45:00Z',
					},
					{
						id: 3,
						title: 'New Song Ideas',
						description: 'Collection of demos and song ideas',
						workspace_id: 2,
						version_count: 5,
						updated_at: '2023-05-08T09:30:00Z',
					},
				];

				setWorkspaces(workspaceData);
				setRecentProjects(projectData);
				setError(null);
			} catch (err) {
				console.error('Error fetching dashboard data:', err);
				setError('Failed to load dashboard data. Please try again later.');
			} finally {
				setLoading(false);
			}
		};

		fetchData();
	}, []);

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

	return (
		<Container size='xl'>
			<Group
				position='apart'
				mb='xl'
			>
				<Title order={2}>Dashboard</Title>
				<Button
					component={Link}
					to='/workspaces/new'
					leftIcon={<FiPlus size={16} />}
				>
					New Workspace
				</Button>
			</Group>

			<Tabs defaultValue='workspaces'>
				<Tabs.List mb='md'>
					<Tabs.Tab
						value='workspaces'
						icon={<FiGrid size={14} />}
					>
						My Workspaces
					</Tabs.Tab>
					<Tabs.Tab
						value='recent'
						icon={<FiArchive size={14} />}
					>
						Recent Projects
					</Tabs.Tab>
				</Tabs.List>

				<Tabs.Panel
					value='workspaces'
					pt='xs'
				>
					<Grid>
						{workspaces.map((workspace) => (
							<Grid.Col
								key={workspace.id}
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
										<Text weight={500}>{workspace.name}</Text>
										<Badge color='blue'>{workspace.workspace_type}</Badge>
									</Group>

									<Text
										size='sm'
										color='dimmed'
										mb='md'
									>
										{workspace.description}
									</Text>

									<Text
										size='xs'
										color='dimmed'
										mb='md'
									>
										{workspace.project_count} projects
									</Text>

									<Button
										component={Link}
										to={`/workspaces/${workspace.id}`}
										variant='light'
										color='blue'
										fullWidth
										mt='md'
										radius='md'
									>
										View Workspace
									</Button>
								</Card>
							</Grid.Col>
						))}
					</Grid>
				</Tabs.Panel>

				<Tabs.Panel
					value='recent'
					pt='xs'
				>
					<Grid>
						{recentProjects.map((project) => (
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
										to={`/workspaces/${project.workspace_id}/projects/${project.id}`}
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
			</Tabs>
		</Container>
	);
};

export default DashboardPage;
