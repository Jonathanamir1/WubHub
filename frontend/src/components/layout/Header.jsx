import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
	Group,
	Button,
	Title,
	Box,
	Menu,
	Avatar,
	Text,
	UnstyledButton,
} from '@mantine/core';
import { useAuth } from '../../contexts/AuthContext';

// Import icons
import { FiLogOut, FiUser, FiMusic, FiPlus, FiGrid } from 'react-icons/fi';

const Header = () => {
	const { currentUser, isAuthenticated, logout } = useAuth();
	const navigate = useNavigate();

	const handleLogout = () => {
		logout();
		navigate('/');
	};

	return (
		<MantineHeader
			height={60}
			p='xs'
		>
			{' '}
			// Use the renamed component here
			<Group
				position='apart'
				sx={{ height: '100%' }}
			>
				<Group>
					<Title
						order={1}
						size='h3'
					>
						<Link
							to='/'
							style={{ textDecoration: 'none', color: 'inherit' }}
						>
							WubHub
						</Link>
					</Title>
				</Group>

				<Group>
					{isAuthenticated ? (
						<>
							<Button
								component={Link}
								to='/workspaces/new'
								variant='outline'
								leftIcon={<FiPlus size={14} />}
							>
								New Workspace
							</Button>

							<Menu
								width={200}
								position='bottom-end'
							>
								<Menu.Target>
									<UnstyledButton>
										<Group>
											<Avatar
												src={currentUser.profile_image}
												radius='xl'
												size='sm'
											/>
											<Text
												weight={500}
												size='sm'
												mr={3}
											>
												{currentUser.username}
											</Text>
										</Group>
									</UnstyledButton>
								</Menu.Target>

								<Menu.Dropdown>
									<Menu.Item
										icon={<FiUser size={14} />}
										component={Link}
										to='/profile'
									>
										Profile
									</Menu.Item>
									<Menu.Item
										icon={<FiGrid size={14} />}
										component={Link}
										to='/dashboard'
									>
										Dashboard
									</Menu.Item>
									<Menu.Item
										icon={<FiMusic size={14} />}
										component={Link}
										to='/projects'
									>
										My Projects
									</Menu.Item>
									<Menu.Divider />
									<Menu.Item
										icon={<FiLogOut size={14} />}
										onClick={handleLogout}
										color='red'
									>
										Logout
									</Menu.Item>
								</Menu.Dropdown>
							</Menu>
						</>
					) : (
						<>
							<Button
								component={Link}
								to='/login'
								variant='subtle'
							>
								Log In
							</Button>
							<Button
								component={Link}
								to='/register'
							>
								Sign Up
							</Button>
						</>
					)}
				</Group>
			</Group>
		</MantineHeader>
	);
};

export default Header;
