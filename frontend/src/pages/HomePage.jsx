import React from 'react';
import { Link } from 'react-router-dom';
import {
	Title,
	Text,
	Container,
	Button,
	Group,
	List,
	ThemeIcon,
	Grid,
	Card,
	Image,
	useMantineTheme,
} from '@mantine/core';
import { FiCheck, FiUsers, FiLock, FiClock, FiWifi } from 'react-icons/fi';
import { useAuth } from '../contexts/AuthContext';

const HomePage = () => {
	const { isAuthenticated } = useAuth();
	const theme = useMantineTheme();

	const features = [
		{
			icon: <FiWifi size={24} />,
			title: 'Version Control for Audio',
			description:
				'Track changes in your music projects with full version history for audio files, DAW projects, and more.',
		},
		{
			icon: <FiUsers size={24} />,
			title: 'Seamless Collaboration',
			description:
				'Invite songwriters, producers, vocalists and more to work together on projects with defined roles.',
		},
		{
			icon: <FiClock size={24} />,
			title: 'Complete History',
			description:
				'See how your tracks evolve over time with detailed version history and audio waveform visualization.',
		},
		{
			icon: <FiLock size={24} />,
			title: 'Secure Storage',
			description:
				'Keep your projects safe and accessible, with privacy controls to share only with those you choose.',
		},
	];

	return (
		<Container size='xl'>
			{/* Hero Section */}
			<div style={{ textAlign: 'center', padding: '60px 0 80px' }}>
				<Title
					order={1}
					size='h1'
					weight={900}
					align='center'
					style={{ marginBottom: 30, fontSize: '3rem' }}
				>
					Git for Musicians.
					<br />
					<Text
						component='span'
						variant='gradient'
						gradient={{ from: 'blue', to: 'cyan' }}
					>
						Version Control for Music.
					</Text>
				</Title>

				<Text
					color='dimmed'
					align='center'
					size='lg'
					style={{ maxWidth: 600, margin: '0 auto', marginBottom: 40 }}
				>
					WubHub is a collaborative platform that allows musicians, producers,
					and songwriters to track versions, collaborate, and manage music
					projects like software developers use Git.
				</Text>

				<Group position='center'>
					{isAuthenticated ? (
						<Button
							component={Link}
							to='/dashboard'
							size='lg'
							variant='gradient'
							gradient={{ from: 'blue', to: 'cyan' }}
						>
							Go to Dashboard
						</Button>
					) : (
						<>
							<Button
								component={Link}
								to='/register'
								size='lg'
								variant='gradient'
								gradient={{ from: 'blue', to: 'cyan' }}
							>
								Get Started
							</Button>
							<Button
								component={Link}
								to='/login'
								size='lg'
								variant='default'
							>
								Log In
							</Button>
						</>
					)}
				</Group>
			</div>

			{/* Features Section */}
			<Title
				order={2}
				align='center'
				mt={50}
				mb={50}
			>
				Everything You Need for Music Collaboration
			</Title>

			<Grid gutter={50}>
				{features.map((feature, index) => (
					<Grid.Col
						key={index}
						md={6}
					>
						<Group noWrap>
							<ThemeIcon
								size={60}
								radius='md'
								variant='light'
								color={theme.primaryColor}
							>
								{feature.icon}
							</ThemeIcon>

							<div>
								<Text
									weight={700}
									size='lg'
									mb='xs'
								>
									{feature.title}
								</Text>
								<Text color='dimmed'>{feature.description}</Text>
							</div>
						</Group>
					</Grid.Col>
				))}
			</Grid>
		</Container>
	);
};

export default HomePage;
