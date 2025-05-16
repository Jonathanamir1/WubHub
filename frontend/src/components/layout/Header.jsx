import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { FiLogOut, FiUser, FiMenu, FiPlus } from 'react-icons/fi';

const Header = () => {
	const { currentUser, isAuthenticated, logout } = useAuth();
	const navigate = useNavigate();
	const [profileMenuOpen, setProfileMenuOpen] = useState(false);

	const handleLogout = () => {
		logout();
		navigate('/');
	};

	return (
		<header className='bg-ableton-blue-700 h-16 fixed top-0 left-0 right-0 z-10'>
			<div className='h-full flex items-center justify-between px-4'>
				{/* Logo section */}
				<div className='flex items-center'>
					<Link
						to='/'
						className='text-white text-2xl font-bold'
					>
						WubHub
						<span className='text-ableton-blue-300'>.</span>
					</Link>
				</div>

				{/* Action buttons */}
				<div className='flex items-center space-x-4'>
					{isAuthenticated ? (
						<>
							{/* Profile dropdown */}
							<div className='relative'>
								<button
									className='flex items-center space-x-2 text-white focus:outline-none'
									onClick={() => setProfileMenuOpen(!profileMenuOpen)}
								>
									<div className='w-8 h-8 rounded-full bg-ableton-blue-500 flex items-center justify-center text-white font-medium'>
										{currentUser?.username?.charAt(0)?.toUpperCase() || 'U'}
									</div>
									<span className='hidden md:inline truncate max-w-[100px]'>
										{currentUser?.username || 'User'}
									</span>
								</button>

								{profileMenuOpen && (
									<div className='absolute right-0 mt-2 w-48 bg-ableton-dark-300 rounded-md shadow-lg py-1 z-20 border border-ableton-dark-200'>
										<div className='px-4 py-2 text-sm text-gray-300 border-b border-ableton-dark-200'>
											Signed in as <strong>{currentUser?.username}</strong>
										</div>
										<Link
											to='/profile'
											className='block px-4 py-2 text-sm text-gray-300 hover:bg-ableton-dark-200 flex items-center'
											onClick={() => setProfileMenuOpen(false)}
										>
											<FiUser
												className='mr-2'
												size={16}
											/>
											Profile
										</Link>
										<button
											onClick={() => {
												setProfileMenuOpen(false);
												handleLogout();
											}}
											className='block w-full text-left px-4 py-2 text-sm text-red-400 hover:bg-ableton-dark-200 flex items-center'
										>
											<FiLogOut
												className='mr-2'
												size={16}
											/>
											Sign out
										</button>
									</div>
								)}
							</div>
						</>
					) : (
						<>
							<Link
								to='/login'
								className='text-white hover:text-ableton-blue-300 px-3 py-1.5 rounded-md text-sm'
							>
								Log In
							</Link>
							<Link
								to='/register'
								className='bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white px-3 py-1.5 rounded-md text-sm'
							>
								Sign Up
							</Link>
						</>
					)}
				</div>
			</div>
		</header>
	);
};

export default Header;
