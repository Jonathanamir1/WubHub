// src/app/dashboard/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { User, Workspace } from '@/lib/types';
import { fetchWorkspaces, getOnboardingStatus } from '@/lib/api';
import Sidebar from '@/components/Sidebar';
import Navbar from '@/components/Navbar';
import OnboardingModal from '@/components/OnboardingModal';

export default function DashboardPage() {
	const router = useRouter();
	const [user, setUser] = useState<User | null>(null);
	const [isLoading, setIsLoading] = useState(true);
	const [showOnboarding, setShowOnboarding] = useState(false);
	const [workspaces, setWorkspaces] = useState<Workspace[]>([]);
	const [currentWorkspace, setCurrentWorkspace] = useState<Workspace | null>(
		null
	);

	useEffect(() => {
		const token = localStorage.getItem('wubhub_token');
		const userData = localStorage.getItem('wubhub_user');

		if (!token) {
			router.push('/login');
			return;
		}

		if (userData) {
			setUser(JSON.parse(userData));
		}

		// Check if user needs onboarding
		checkForOnboarding(token);
	}, [router]);

	const checkForOnboarding = async (token: string) => {
		try {
			// For now, check localStorage until backend is ready
			const hasCompletedOnboarding = localStorage.getItem(
				'wubhub_onboarding_completed'
			);

			if (!hasCompletedOnboarding) {
				console.log('User needs onboarding, showing modal...');
				setShowOnboarding(true);
			} else {
				console.log('User has completed onboarding');
			}

			// Fetch workspaces
			const workspacesResult = await fetchWorkspaces(token);
			if (workspacesResult.success) {
				setWorkspaces(workspacesResult.data);
				console.log('Loaded workspaces:', workspacesResult.data);

				// Set first workspace as current if available
				if (workspacesResult.data.length > 0) {
					setCurrentWorkspace(workspacesResult.data[0]);
				}
			} else if (workspacesResult.status === 401) {
				localStorage.removeItem('wubhub_token');
				localStorage.removeItem('wubhub_user');
				router.push('/login');
			}
		} catch (error) {
			console.error('Failed to check onboarding/workspaces:', error);
		} finally {
			setIsLoading(false);
		}
	};

	const handleOnboardingComplete = () => {
		console.log('Onboarding completed, closing modal...');
		setShowOnboarding(false);
		// DON'T reload the page - just refresh the workspaces
		const token = localStorage.getItem('wubhub_token');
		if (token) {
			fetchWorkspacesOnly(token);
		}
	};

	const fetchWorkspacesOnly = async (token: string) => {
		try {
			const workspacesResult = await fetchWorkspaces(token);
			if (workspacesResult.success) {
				setWorkspaces(workspacesResult.data);
				console.log('Refreshed workspaces:', workspacesResult.data);

				// Set first workspace as current if none selected
				if (!currentWorkspace && workspacesResult.data.length > 0) {
					setCurrentWorkspace(workspacesResult.data[0]);
				}
			}
		} catch (error) {
			console.error('Failed to refresh workspaces:', error);
		}
	};

	const handleWorkspaceCreated = (workspace: Workspace) => {
		setWorkspaces((prev) => [...prev, workspace]);
		setCurrentWorkspace(workspace);
	};

	const handleWorkspaceChange = (workspace: Workspace) => {
		setCurrentWorkspace(workspace);
	};

	const handleLogout = () => {
		localStorage.removeItem('wubhub_token');
		localStorage.removeItem('wubhub_user');
		router.push('/login');
	};

	if (isLoading) {
		return (
			<div className='min-h-screen bg-dark-800 flex items-center justify-center'>
				<div className='text-white'>Loading...</div>
			</div>
		);
	}

	return (
		<div className='min-h-screen bg-dark-800 flex flex-col'>
			{/* Notion-style Navbar */}
			<Navbar
				user={user}
				onLogout={handleLogout}
				title={currentWorkspace ? currentWorkspace.name : 'Dashboard'}
				currentWorkspace={currentWorkspace}
				onWorkspaceChange={handleWorkspaceChange}
			/>

			<div className='flex flex-1'>
				{/* Workspace-focused Sidebar */}
				{/* <Sidebar currentWorkspace={currentWorkspace} /> */}

				{/* Main Content Area */}
				<div className='flex-1'>
					<main className='p-6'>
						{currentWorkspace ? (
							<div>
								<div className='mb-6'>
									<h1 className='text-2xl font-bold text-white mb-2'>
										Welcome to {currentWorkspace.name}
									</h1>
									<p className='text-dark-400'>
										{currentWorkspace.description ||
											'Start organizing your music projects'}
									</p>
								</div>

								{/* Quick Actions */}
								<div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8'>
									<div className='card p-6 hover:border-accent-blue transition-colors cursor-pointer'>
										<div className='text-3xl mb-3'>🎤</div>
										<h3 className='text-lg font-semibold text-white mb-2'>
											Start Recording
										</h3>
										<p className='text-sm text-dark-400'>
											Begin a new recording session
										</p>
									</div>

									<div className='card p-6 hover:border-accent-blue transition-colors cursor-pointer'>
										<div className='text-3xl mb-3'>📝</div>
										<h3 className='text-lg font-semibold text-white mb-2'>
											Write Lyrics
										</h3>
										<p className='text-sm text-dark-400'>
											Create and organize your lyrics
										</p>
									</div>

									<div className='card p-6 hover:border-accent-blue transition-colors cursor-pointer'>
										<div className='text-3xl mb-3'>🎵</div>
										<h3 className='text-lg font-semibold text-white mb-2'>
											New Project
										</h3>
										<p className='text-sm text-dark-400'>
											Start a fresh music project
										</p>
									</div>
								</div>

								{/* Recent Activity */}
								<div className='card p-6'>
									<h2 className='text-lg font-semibold text-white mb-4'>
										Recent Activity
									</h2>
									<div className='space-y-3'>
										<div className='flex items-center gap-3 text-sm'>
											<div className='w-2 h-2 bg-green-500 rounded-full'></div>
											<span className='text-dark-300'>
												Created new workspace
											</span>
											<span className='text-dark-500'>2 minutes ago</span>
										</div>
										<div className='text-center py-8 text-dark-500'>
											<p>No recent activity. Start creating!</p>
										</div>
									</div>
								</div>
							</div>
						) : (
							<div className='text-center py-12'>
								<div className='text-6xl mb-4'>🎵</div>
								<h2 className='text-xl font-semibold text-white mb-2'>
									Welcome to WubHub
								</h2>
								<p className='text-dark-400 mb-6 max-w-md mx-auto'>
									Select a workspace from the dropdown in the navbar to get
									started, or create a new one to begin your music collaboration
									journey.
								</p>
							</div>
						)}
					</main>
				</div>
			</div>

			{/* Onboarding Modal */}
			<OnboardingModal
				isOpen={showOnboarding}
				onComplete={handleOnboardingComplete}
				onWorkspaceCreated={handleWorkspaceCreated}
				isFirstTime={true}
			/>
		</div>
	);
}
