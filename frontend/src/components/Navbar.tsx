// src/components/Navbar.tsx
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { User } from '@/lib/types';

interface NavbarProps {
	user: User | null;
	onLogout: () => void;
	title?: string;
}

export default function Navbar({
	user,
	onLogout,
	title = 'Dashboard',
}: NavbarProps) {
	const router = useRouter();
	const [showUserMenu, setShowUserMenu] = useState(false);
	const [showSupportMenu, setShowSupportMenu] = useState(false);
	const [searchQuery, setSearchQuery] = useState('');

	const handleBack = () => {
		router.back();
	};

	const handleForward = () => {
		router.forward();
	};

	const handleSearch = (e: React.FormEvent) => {
		e.preventDefault();
		// TODO: Implement search functionality
		console.log('Search query:', searchQuery);
	};

	const handleSupportClick = (type: string) => {
		setShowSupportMenu(false);
		// TODO: Implement support actions
		console.log('Support action:', type);
	};

	return (
		<nav className='bg-dark-900 border-b border-dark-600 px-4 py-3'>
			<div className='flex items-center justify-between'>
				{/* Left Section - Logo, Navigation & Title */}
				<div className='flex items-center gap-4'>
					{/* Logo */}
					<div className='flex items-center gap-2'>
						<span className='text-xl font-bold text-white'>wubhub</span>
					</div>

					{/* Divider */}
					<div className='w-px h-6 bg-dark-600'></div>

					{/* Back/Forward Buttons */}
					<div className='flex items-center gap-1'>
						<button
							onClick={handleBack}
							className='w-8 h-8 rounded-md bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-dark-300 hover:text-white transition-colors'
							title='Go back'
						>
							<svg
								width='16'
								height='16'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
							>
								<path d='M19 12H5m7 7-7-7 7-7' />
							</svg>
						</button>
						<button
							onClick={handleForward}
							className='w-8 h-8 rounded-md bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-dark-300 hover:text-white transition-colors'
							title='Go forward'
						>
							<svg
								width='16'
								height='16'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
							>
								<path d='M5 12h14m-7-7 7 7-7 7' />
							</svg>
						</button>
					</div>

					{/* Page Title */}
					<h1 className='text-lg font-semibold text-white'>{title}</h1>
				</div>

				{/* Center Section - Search Bar */}
				<div className='flex-1 max-w-md mx-8'>
					<form
						onSubmit={handleSearch}
						className='relative'
					>
						<div className='relative'>
							<div className='absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none'>
								<svg
									width='16'
									height='16'
									viewBox='0 0 24 24'
									fill='none'
									stroke='currentColor'
									strokeWidth='2'
									className='text-dark-400'
								>
									<circle
										cx='11'
										cy='11'
										r='8'
									/>
									<path d='M21 21l-4.35-4.35' />
								</svg>
							</div>
							<input
								type='text'
								value={searchQuery}
								onChange={(e) => setSearchQuery(e.target.value)}
								className='w-full pl-10 pr-4 py-2 bg-dark-700 border border-dark-600 rounded-md text-white placeholder-dark-400 focus:outline-none focus:ring-2 focus:ring-accent-blue focus:border-transparent'
								placeholder='Search workspaces, projects...'
							/>
						</div>
					</form>
				</div>

				{/* Right Section - Support & User Menu */}
				<div className='flex items-center gap-3'>
					{/* Support Menu */}
					<div className='relative'>
						<button
							onClick={() => setShowSupportMenu(!showSupportMenu)}
							className='w-8 h-8 rounded-md bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-dark-300 hover:text-white transition-colors'
							title='Help & Support'
						>
							<svg
								width='16'
								height='16'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
							>
								<circle
									cx='12'
									cy='12'
									r='10'
								/>
								<path d='M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3' />
								<path d='M12 17h.01' />
							</svg>
						</button>

						{showSupportMenu && (
							<div className='absolute right-0 mt-2 w-48 bg-dark-800 border border-dark-600 rounded-md shadow-lg z-50'>
								<div className='py-1'>
									<button
										onClick={() => handleSupportClick('help')}
										className='w-full text-left px-4 py-2 text-sm text-dark-300 hover:bg-dark-700 hover:text-white'
									>
										📚 Help Center
									</button>
									<button
										onClick={() => handleSupportClick('contact')}
										className='w-full text-left px-4 py-2 text-sm text-dark-300 hover:bg-dark-700 hover:text-white'
									>
										💬 Contact Support
									</button>
									<button
										onClick={() => handleSupportClick('feedback')}
										className='w-full text-left px-4 py-2 text-sm text-dark-300 hover:bg-dark-700 hover:text-white'
									>
										💡 Send Feedback
									</button>
									<button
										onClick={() => handleSupportClick('shortcuts')}
										className='w-full text-left px-4 py-2 text-sm text-dark-300 hover:bg-dark-700 hover:text-white'
									>
										⌨️ Keyboard Shortcuts
									</button>
								</div>
							</div>
						)}
					</div>

					{/* Notifications (placeholder for future) */}
					<button
						className='w-8 h-8 rounded-md bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-dark-300 hover:text-white transition-colors relative'
						title='Notifications'
					>
						<svg
							width='16'
							height='16'
							viewBox='0 0 24 24'
							fill='none'
							stroke='currentColor'
							strokeWidth='2'
						>
							<path d='M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9' />
							<path d='M13.73 21a2 2 0 0 1-3.46 0' />
						</svg>
						{/* Notification badge (example) */}
						{/* <span className="absolute -top-1 -right-1 w-3 h-3 bg-red-500 rounded-full"></span> */}
					</button>

					{/* User Menu */}
					<div className='relative'>
						<button
							onClick={() => setShowUserMenu(!showUserMenu)}
							className='flex items-center gap-2 px-2 py-1 rounded-md hover:bg-dark-700 transition-colors'
						>
							{user?.profile_image_url ? (
								<img
									src={user.profile_image_url}
									alt={user.username}
									className='w-8 h-8 rounded-full'
								/>
							) : (
								<div className='w-8 h-8 bg-accent-blue rounded-full flex items-center justify-center text-sm font-medium text-dark-900'>
									{user?.username?.charAt(0).toUpperCase() || 'U'}
								</div>
							)}
							<div className='hidden sm:block text-left'>
								<div className='text-sm font-medium text-white'>
									{user?.username || 'User'}
								</div>
							</div>
							<svg
								width='12'
								height='12'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
								className='text-dark-400'
							>
								<path d='M6 9l6 6 6-6' />
							</svg>
						</button>

						{showUserMenu && (
							<div className='absolute right-0 mt-2 w-48 bg-dark-800 border border-dark-600 rounded-md shadow-lg z-50'>
								<div className='px-4 py-3 border-b border-dark-600'>
									<div className='text-sm font-medium text-white'>
										{user?.username}
									</div>
									<div className='text-xs text-dark-400'>{user?.email}</div>
								</div>
								<div className='py-1'>
									<button
										onClick={() => {
											setShowUserMenu(false);
											// TODO: Navigate to profile
										}}
										className='w-full text-left px-4 py-2 text-sm text-dark-300 hover:bg-dark-700 hover:text-white'
									>
										👤 Profile Settings
									</button>
									<button
										onClick={() => {
											setShowUserMenu(false);
											// TODO: Navigate to account settings
										}}
										className='w-full text-left px-4 py-2 text-sm text-dark-300 hover:bg-dark-700 hover:text-white'
									>
										⚙️ Account Settings
									</button>
									<button
										onClick={() => {
											setShowUserMenu(false);
											// TODO: Navigate to billing
										}}
										className='w-full text-left px-4 py-2 text-sm text-dark-300 hover:bg-dark-700 hover:text-white'
									>
										💳 Billing
									</button>
									<div className='border-t border-dark-600 my-1'></div>
									<button
										onClick={() => {
											setShowUserMenu(false);
											onLogout();
										}}
										className='w-full text-left px-4 py-2 text-sm text-dark-300 hover:bg-dark-700 hover:text-white'
									>
										🚪 Sign Out
									</button>
								</div>
							</div>
						)}
					</div>
				</div>
			</div>

			{/* Click outside to close menus */}
			{(showUserMenu || showSupportMenu) && (
				<div
					className='fixed inset-0 z-40'
					onClick={() => {
						setShowUserMenu(false);
						setShowSupportMenu(false);
					}}
				/>
			)}
		</nav>
	);
}
