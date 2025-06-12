// src/components/Navbar.tsx
'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { User, Workspace } from '@/lib/types';
import { fetchWorkspaces } from '@/lib/api';
import OnboardingModal from '@/components/OnboardingModal';
import WorkspaceSettingsModal from '@/components/WorkspaceSettingsModal';

interface NavbarProps {
	user: User | null;
	onLogout: () => void;
	currentWorkspace?: Workspace | null;
	onWorkspaceChange?: (workspace: Workspace) => void;
	onWorkspaceCreated?: (workspace: Workspace) => void;
}

export default function Navbar({
	user,
	onLogout,
	currentWorkspace,
	onWorkspaceChange,
	onWorkspaceCreated,
}: NavbarProps) {
	const router = useRouter();
	const [showUserMenu, setShowUserMenu] = useState(false);
	const [showWorkspaceMenu, setShowWorkspaceMenu] = useState(false);
	const [showAddWorkspaceModal, setShowAddWorkspaceModal] = useState(false);
	const [showWorkspaceSettingsModal, setShowWorkspaceSettingsModal] =
		useState(false);
	const [workspaces, setWorkspaces] = useState<Workspace[]>([]);
	const [isLoadingWorkspaces, setIsLoadingWorkspaces] = useState(false);

	const userMenuRef = useRef<HTMLDivElement>(null);
	const workspaceMenuRef = useRef<HTMLDivElement>(null);

	// Close dropdowns when clicking outside
	useEffect(() => {
		const handleClickOutside = (event: MouseEvent) => {
			if (
				userMenuRef.current &&
				!userMenuRef.current.contains(event.target as Node)
			) {
				setShowUserMenu(false);
			}
			if (
				workspaceMenuRef.current &&
				!workspaceMenuRef.current.contains(event.target as Node)
			) {
				setShowWorkspaceMenu(false);
			}
		};

		document.addEventListener('mousedown', handleClickOutside);
		return () => document.removeEventListener('mousedown', handleClickOutside);
	}, []);

	// Load workspaces when dropdown opens
	const handleWorkspaceMenuToggle = async () => {
		if (!showWorkspaceMenu && !isLoadingWorkspaces) {
			setIsLoadingWorkspaces(true);
			const token = localStorage.getItem('wubhub_token');
			if (token) {
				try {
					const result = await fetchWorkspaces(token);
					if (result.success) {
						setWorkspaces(result.data);
					}
				} catch (error) {
					console.error('Failed to load workspaces:', error);
				}
			}
			setIsLoadingWorkspaces(false);
		}
		setShowWorkspaceMenu(!showWorkspaceMenu);
	};

	const handleBack = () => {
		router.back();
	};

	const handleForward = () => {
		router.forward();
	};

	const handleWorkspaceSelect = (workspace: Workspace) => {
		onWorkspaceChange?.(workspace);
		setShowWorkspaceMenu(false);
	};

	const handleAddWorkspace = () => {
		setShowWorkspaceMenu(false);
		setShowAddWorkspaceModal(true);
	};

	const handleWorkspaceModalComplete = () => {
		setShowAddWorkspaceModal(false);
		// Refresh workspaces in dropdown
		const token = localStorage.getItem('wubhub_token');
		if (token) {
			fetchWorkspaces(token).then((result) => {
				if (result.success) {
					setWorkspaces(result.data);
				}
			});
		}
	};

	const handleNewWorkspaceCreated = (workspace: Workspace) => {
		setWorkspaces((prev) => [...prev, workspace]);
		onWorkspaceCreated?.(workspace);
	};

	const handleWorkspaceSettings = () => {
		setShowWorkspaceMenu(false);
		setShowWorkspaceSettingsModal(true);
	};

	const handleWorkspaceDeleted = (workspaceId: number) => {
		setWorkspaces((prev) => prev.filter((w) => w.id !== workspaceId));
		// If the deleted workspace was the current one, clear current workspace
		if (currentWorkspace?.id === workspaceId) {
			onWorkspaceChange?.(workspaces.find((w) => w.id !== workspaceId) || null);
		}
	};

	// Calculate dynamic width based on workspace name length
	const getWorkspaceSelectorWidth = () => {
		if (!currentWorkspace) {
			return 'min-w-[160px] sm:min-w-[180px] max-w-[200px] sm:max-w-[240px]';
		}

		const nameLength = currentWorkspace.name.length;

		if (nameLength <= 15) {
			return 'min-w-[160px] sm:min-w-[180px] max-w-[220px] sm:max-w-[260px]';
		} else if (nameLength <= 25) {
			return 'min-w-[200px] sm:min-w-[240px] max-w-[280px] sm:max-w-[320px]';
		} else if (nameLength <= 35) {
			return 'min-w-[240px] sm:min-w-[280px] max-w-[320px] sm:max-w-[380px]';
		} else {
			return 'min-w-[280px] sm:min-w-[320px] max-w-[360px] sm:max-w-[400px]';
		}
	};

	return (
		<>
			<nav className='h-14 bg-dark-900 border-b border-dark-600 flex items-center justify-between px-3 sm:px-4 lg:px-6'>
				{/* Left Section - Workspace Selector, Navigation */}
				<div className='flex items-center gap-2 sm:gap-3 lg:gap-4 flex-1'>
					{/* Workspace Selector */}
					<div
						className='relative'
						ref={workspaceMenuRef}
					>
						<button
							onClick={handleWorkspaceMenuToggle}
							className='flex items-center gap-2 sm:gap-3 px-3 sm:px-4 py-2 text-sm bg-dark-800 hover:bg-dark-700 rounded-lg border border-dark-600 hover:border-dark-500 transition-all min-w-[160px] sm:min-w-[200px] lg:min-w-[240px] justify-between max-w-[240px] sm:max-w-[300px] lg:max-w-[400px] h-10'
						>
							<div className='flex items-center gap-2 sm:gap-3 min-w-0 flex-1'>
								{currentWorkspace ? (
									<>
										<div className='w-6 h-6 bg-gradient-to-br from-accent-blue to-blue-600 rounded-md flex items-center justify-center text-xs font-bold text-white shrink-0'>
											{currentWorkspace.name.charAt(0).toUpperCase()}
										</div>
										<span className='text-white font-medium truncate text-sm leading-none'>
											{currentWorkspace.name}
										</span>
									</>
								) : (
									<>
										<div className='w-6 h-6 bg-dark-600 rounded-md flex items-center justify-center shrink-0'>
											<svg
												width='12'
												height='12'
												viewBox='0 0 24 24'
												fill='none'
												stroke='currentColor'
												strokeWidth='2'
											>
												<path d='M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z' />
											</svg>
										</div>
										<span className='text-dark-300 font-medium text-sm truncate leading-none'>
											<span className='hidden sm:inline'>Select workspace</span>
											<span className='sm:hidden'>Workspace</span>
										</span>
									</>
								)}
							</div>
							<svg
								width='14'
								height='14'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
								className={`text-dark-400 transition-transform shrink-0 ${
									showWorkspaceMenu ? 'rotate-180' : ''
								}`}
							>
								<path d='M6 9l6 6 6-6' />
							</svg>
						</button>

						{/* Workspace Dropdown */}
						{showWorkspaceMenu && (
							<div className='absolute top-full left-0 mt-2 w-72 sm:w-80 lg:w-96 bg-dark-800 border border-dark-600 rounded-lg shadow-xl z-50'>
								<div className='p-2 sm:p-3'>
									<div className='text-xs font-semibold text-dark-400 uppercase tracking-wider px-2 sm:px-3 py-2 mb-2'>
										Your Workspaces
									</div>

									{isLoadingWorkspaces ? (
										<div className='px-3 py-8 text-sm text-dark-400 text-center'>
											<div className='animate-spin w-5 h-5 border-2 border-dark-600 border-t-accent-blue rounded-full mx-auto mb-2'></div>
											Loading workspaces...
										</div>
									) : workspaces.length === 0 ? (
										<div className='px-3 py-8 text-center'>
											<div className='text-3xl sm:text-4xl mb-3'>🎵</div>
											<div className='text-sm text-dark-400 mb-4'>
												No workspaces yet
											</div>
											<button
												onClick={handleAddWorkspace}
												className='btn-primary text-sm px-4 py-2'
											>
												Create your first workspace
											</button>
										</div>
									) : (
										<div className='space-y-1 max-h-60 sm:max-h-80 overflow-y-auto'>
											{workspaces.map((workspace) => (
												<div key={workspace.id}>
													{/* Workspace Button */}
													<button
														onClick={() => handleWorkspaceSelect(workspace)}
														className={`w-full flex items-center gap-3 px-2 sm:px-3 py-2 sm:py-3 text-sm rounded-lg hover:bg-dark-700 transition-colors text-left ${
															currentWorkspace?.id === workspace.id
																? 'bg-dark-700 ring-1 ring-accent-blue'
																: ''
														}`}
													>
														<div className='w-7 h-7 sm:w-8 sm:h-8 bg-gradient-to-br from-accent-blue to-blue-600 rounded-lg flex items-center justify-center text-sm font-bold text-white shrink-0'>
															{workspace.name.charAt(0).toUpperCase()}
														</div>
														<div className='flex-1 min-w-0'>
															<div
																className={`font-medium truncate ${
																	currentWorkspace?.id === workspace.id
																		? 'text-white'
																		: 'text-dark-200'
																}`}
															>
																{workspace.name}
															</div>
															{workspace.description && (
																<div className='text-xs text-dark-500 truncate mt-0.5'>
																	{workspace.description}
																</div>
															)}
														</div>
														{currentWorkspace?.id === workspace.id && (
															<svg
																width='14'
																height='14'
																viewBox='0 0 24 24'
																fill='none'
																stroke='currentColor'
																strokeWidth='2'
																className='text-accent-blue shrink-0 sm:w-4 sm:h-4'
															>
																<path d='M20 6L9 17l-5-5' />
															</svg>
														)}
													</button>

													{/* Workspace Actions - Only show for current workspace */}
													{currentWorkspace?.id === workspace.id && (
														<div className='mx-2 sm:mx-3 mt-2 mb-1'>
															<div className='flex gap-2'>
																<button
																	onClick={handleWorkspaceSettings}
																	className='flex-1 flex items-center justify-center gap-2 px-3 py-2 text-xs text-dark-400 hover:text-white hover:bg-dark-600 rounded-md transition-colors'
																	title='Workspace settings'
																>
																	<svg
																		width='12'
																		height='12'
																		viewBox='0 0 24 24'
																		fill='none'
																		stroke='currentColor'
																		strokeWidth='2'
																	>
																		<circle
																			cx='12'
																			cy='12'
																			r='3'
																		/>
																		<path d='M12 1v6m0 6v6' />
																		<path d='m9 12-6.93-4M15 12l6.93 4' />
																	</svg>
																	<span className='hidden sm:inline'>
																		Settings
																	</span>
																</button>
																<button
																	className='flex-1 flex items-center justify-center gap-2 px-3 py-2 text-xs text-dark-400 hover:text-white hover:bg-dark-600 rounded-md transition-colors'
																	title='Invite collaborators'
																>
																	<svg
																		width='12'
																		height='12'
																		viewBox='0 0 24 24'
																		fill='none'
																		stroke='currentColor'
																		strokeWidth='2'
																	>
																		<path d='M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2' />
																		<circle
																			cx='9'
																			cy='7'
																			r='4'
																		/>
																		<line
																			x1='19'
																			y1='8'
																			x2='24'
																			y2='8'
																		/>
																		<line
																			x1='21.5'
																			y1='6.5'
																			x2='21.5'
																			y2='9.5'
																		/>
																	</svg>
																	<span className='hidden sm:inline'>
																		Invite
																	</span>
																</button>
															</div>
														</div>
													)}
												</div>
											))}
										</div>
									)}

									{workspaces.length > 0 && (
										<div className='border-t border-dark-600 mt-3 pt-3'>
											<button
												onClick={handleAddWorkspace}
												className='w-full flex items-center gap-3 px-2 sm:px-3 py-2 text-sm text-dark-400 hover:text-white hover:bg-dark-700 rounded-lg transition-colors'
											>
												<div className='w-7 h-7 sm:w-8 sm:h-8 bg-dark-700 border-2 border-dashed border-dark-500 rounded-lg flex items-center justify-center shrink-0'>
													<svg
														width='14'
														height='14'
														viewBox='0 0 24 24'
														fill='none'
														stroke='currentColor'
														strokeWidth='2'
														className='sm:w-4 sm:h-4'
													>
														<path d='M12 5v14m-7-7h14' />
													</svg>
												</div>
												<span className='font-medium'>Add workspace</span>
											</button>
										</div>
									)}
								</div>
							</div>
						)}
					</div>

					{/* Divider - Hidden on mobile */}
					<div className='w-px h-4 sm:h-6 bg-dark-600 hidden sm:block'></div>
					<div className='flex items-center gap-1 ml-auto sm:ml-0'>
						<button
							onClick={handleBack}
							className='w-7 h-7 sm:w-8 sm:h-8 rounded-lg bg-dark-800 hover:bg-dark-700 border border-dark-600 hover:border-dark-500 flex items-center justify-center text-dark-300 hover:text-white transition-all'
							title='Go back'
						>
							<svg
								width='12'
								height='12'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
								className='sm:w-3.5 sm:h-3.5'
							>
								<path d='M19 12H5m7 7-7-7 7-7' />
							</svg>
						</button>
						<button
							onClick={handleForward}
							className='w-7 h-7 sm:w-8 sm:h-8 rounded-lg bg-dark-800 hover:bg-dark-700 border border-dark-600 hover:border-dark-500 flex items-center justify-center text-dark-300 hover:text-white transition-all'
							title='Go forward'
						>
							<svg
								width='12'
								height='12'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
								className='sm:w-3.5 sm:h-3.5'
							>
								<path d='M5 12h14m-7-7 7 7-7 7' />
							</svg>
						</button>
					</div>
				</div>

				{/* Right Section - User Menu */}
				<div className='flex items-center ml-2'>
					{/* User Menu */}
					<div
						className='relative'
						ref={userMenuRef}
					>
						<button
							onClick={() => setShowUserMenu(!showUserMenu)}
							className='w-7 h-7 sm:w-8 sm:h-8 bg-gradient-to-br from-accent-blue to-blue-600 rounded-lg flex items-center justify-center text-sm font-bold text-white hover:from-blue-500 hover:to-blue-700 transition-all'
						>
							{user?.username?.charAt(0).toUpperCase() || 'U'}
						</button>

						{/* User Dropdown */}
						{showUserMenu && (
							<div className='absolute top-full right-0 mt-2 w-64 sm:w-72 bg-dark-800 border border-dark-600 rounded-lg shadow-xl z-50'>
								<div className='p-2 sm:p-3'>
									{user && (
										<div className='px-2 sm:px-3 py-3 sm:py-4 border-b border-dark-600 mb-2'>
											<div className='flex items-center gap-3'>
												<div className='w-8 h-8 sm:w-10 sm:h-10 bg-gradient-to-br from-accent-blue to-blue-600 rounded-lg flex items-center justify-center text-sm font-bold text-white'>
													{user.username.charAt(0).toUpperCase()}
												</div>
												<div className='flex-1 min-w-0'>
													<p className='text-sm font-semibold text-white truncate'>
														{user.username}
													</p>
													<p className='text-xs text-dark-400 truncate'>
														{user.email}
													</p>
												</div>
											</div>
										</div>
									)}

									<div className='space-y-1'>
										<button className='w-full flex items-center gap-3 px-2 sm:px-3 py-2 text-sm text-dark-300 hover:text-white hover:bg-dark-700 rounded-lg transition-colors'>
											<svg
												width='14'
												height='14'
												viewBox='0 0 24 24'
												fill='none'
												stroke='currentColor'
												strokeWidth='2'
												className='sm:w-4 sm:h-4'
											>
												<path d='M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2' />
												<circle
													cx='12'
													cy='7'
													r='4'
												/>
											</svg>
											<span className='truncate'>Profile settings</span>
										</button>
										<button className='w-full flex items-center gap-3 px-2 sm:px-3 py-2 text-sm text-dark-300 hover:text-white hover:bg-dark-700 rounded-lg transition-colors'>
											<svg
												width='14'
												height='14'
												viewBox='0 0 24 24'
												fill='none'
												stroke='currentColor'
												strokeWidth='2'
												className='sm:w-4 sm:h-4'
											>
												<circle
													cx='12'
													cy='12'
													r='3'
												/>
												<path d='M12 1v6m0 6v6' />
												<path d='m9 12-6.93-4M15 12l6.93 4' />
											</svg>
											<span className='truncate'>Preferences</span>
										</button>
										<button className='w-full flex items-center gap-3 px-2 sm:px-3 py-2 text-sm text-dark-300 hover:text-white hover:bg-dark-700 rounded-lg transition-colors'>
											<svg
												width='14'
												height='14'
												viewBox='0 0 24 24'
												fill='none'
												stroke='currentColor'
												strokeWidth='2'
												className='sm:w-4 sm:h-4'
											>
												<circle
													cx='11'
													cy='11'
													r='8'
												/>
												<path d='m21 21-4.35-4.35' />
											</svg>
											<span className='truncate'>Search</span>
										</button>
										<button className='w-full flex items-center gap-3 px-2 sm:px-3 py-2 text-sm text-dark-300 hover:text-white hover:bg-dark-700 rounded-lg transition-colors'>
											<svg
												width='14'
												height='14'
												viewBox='0 0 24 24'
												fill='none'
												stroke='currentColor'
												strokeWidth='2'
												className='sm:w-4 sm:h-4'
											>
												<path d='M6 8a6 6 0 0112 0c0 7 3 9 3 9H3s3-2 3-9' />
												<path d='M13.73 21a2 2 0 01-3.46 0' />
											</svg>
											<span className='truncate'>Notifications</span>
										</button>
										<button className='w-full flex items-center gap-3 px-2 sm:px-3 py-2 text-sm text-dark-300 hover:text-white hover:bg-dark-700 rounded-lg transition-colors'>
											<svg
												width='14'
												height='14'
												viewBox='0 0 24 24'
												fill='none'
												stroke='currentColor'
												strokeWidth='2'
												className='sm:w-4 sm:h-4'
											>
												<circle
													cx='12'
													cy='12'
													r='10'
												/>
												<path d='M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3' />
												<path d='M12 17h.01' />
											</svg>
											<span className='truncate'>Help & Support</span>
										</button>
									</div>

									<div className='border-t border-dark-600 mt-2 pt-2'>
										<button
											onClick={onLogout}
											className='w-full flex items-center gap-3 px-2 sm:px-3 py-2 text-sm text-dark-300 hover:text-white hover:bg-dark-700 rounded-lg transition-colors'
										>
											<svg
												width='14'
												height='14'
												viewBox='0 0 24 24'
												fill='none'
												stroke='currentColor'
												strokeWidth='2'
												className='sm:w-4 sm:h-4'
											>
												<path d='M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4' />
												<polyline points='16,17 21,12 16,7' />
												<line
													x1='21'
													y1='12'
													x2='9'
													y2='12'
												/>
											</svg>
											<span className='truncate'>Sign out</span>
										</button>
									</div>
								</div>
							</div>
						)}
					</div>
				</div>
			</nav>

			{/* Add Workspace Modal */}
			<OnboardingModal
				isOpen={showAddWorkspaceModal}
				onComplete={handleWorkspaceModalComplete}
				onWorkspaceCreated={handleNewWorkspaceCreated}
				isFirstTime={false}
			/>

			{/* Workspace Settings Modal */}
			<WorkspaceSettingsModal
				isOpen={showWorkspaceSettingsModal}
				onClose={() => setShowWorkspaceSettingsModal(false)}
				workspace={currentWorkspace}
				onWorkspaceDeleted={handleWorkspaceDeleted}
			/>
		</>
	);
}
