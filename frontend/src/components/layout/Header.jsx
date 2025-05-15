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
	Divider,
	Paper,
} from '@mantine/core';
import { useAuth } from '../../contexts/AuthContext';
import { FiLogOut, FiUser, FiMusic, FiPlus, FiLayout } from 'react-icons/fi';

const Header = () => {
	const { currentUser, isAuthenticated, logout } = useAuth();
	const navigate = useNavigate();

	const handleLogout = () => {
		logout();
		navigate('/');
	};

	return (
		<Paper
			shadow='sm'
			p='md'
			sx={(theme) => ({
				backgroundColor: theme.colors.blue[7],
				height: 70,
				display: 'flex',
				alignItems: 'center',
				position: 'sticky',
				top: 0,
				zIndex: 100,
				borderRadius: 0,
			})}
		>
			<Group
				position='apart'
				sx={{ width: '100%' }}
			>
				<Group>
					<Title
						order={1}
						size='h3'
					>
						<Link
							to='/'
							style={{ textDecoration: 'none', color: 'white' }}
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
								to='/projects/new'
								variant='filled'
								color='cyan'
								leftIcon={<FiPlus size={14} />}
								radius='md'
							>
								New Project
							</Button>

							<Menu
								width={200}
								position='bottom-end'
								shadow='md'
							>
								<Menu.Target>
									<UnstyledButton>
										<Group>
											<Avatar
												src={currentUser.profile_image}
												radius='xl'
												size='md'
												color='cyan'
											/>
											<Box>
												<Text
													weight={600}
													size='sm'
													color='white'
												>
													{currentUser.username}
												</Text>
											</Box>
										</Group>
									</UnstyledButton>
								</Menu.Target>

								<Menu.Dropdown>
									<Menu.Label>Account</Menu.Label>
									<Menu.Item
										icon={<FiUser size={14} />}
										component={Link}
										to='/profile'
									>
										Profile
									</Menu.Item>
									<Menu.Item
										icon={<FiMusic size={14} />}
										component={Link}
										to='/dashboard'
									>
										My Projects
									</Menu.Item>
									<Menu.Item
										icon={<FiLayout size={14} />}
										component={Link}
										to='/dashboard'
									>
										Dashboard
									</Menu.Item>
									<Divider />
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
								color='white'
								radius='md'
							>
								Log In
							</Button>
							<Button
								component={Link}
								to='/register'
								variant='filled'
								color='cyan'
								radius='md'
							>
								Sign Up
							</Button>
						</>
					)}
				</Group>
			</Group>
		</Paper>
	);
};

export default Header;
