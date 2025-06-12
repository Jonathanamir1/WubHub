// src/app/dashboard/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { User, Workspace } from '@/lib/types';
import { fetchWorkspaces } from '@/lib/api';
import Sidebar from '@/components/Sidebar';
import Navbar from '@/components/Navbar';
import OnboardingModal from '@/components/OnboardingModal';

export default function DashboardPage() {
	const router = useRouter();
	const [user, setUser] = useState<User | null>(null);
	const [isLoading, setIsLoading] = useState(true);
	const [showOnboarding, setShowOnboarding] = useState(false);
	const [workspaces, setWorkspaces] = useState<Workspace[]>([]);

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
			const result = await fetchWorkspaces(token);
			if (result.success) {
				setWorkspaces(result.data);

				// Check if user has completed onboarding
				const hasCompletedOnboarding = localStorage.getItem(
					'wubhub_onboarding_completed'
				);

				// Show onboarding only if user has never completed it (first time signup)
				if (!hasCompletedOnboarding) {
					setShowOnboarding(true);
				}
			} else if (result.status === 401) {
				localStorage.removeItem('wubhub_token');
				localStorage.removeItem('wubhub_user');
				router.push('/login');
			}
		} catch (error) {
			console.error('Failed to check workspaces:', error);
		} finally {
			setIsLoading(false);
		}
	};

	const handleOnboardingComplete = () => {
		setShowOnboarding(false);
		// Mark onboarding as completed
		localStorage.setItem('wubhub_onboarding_completed', 'true');
		// Refresh the page to show the new workspace
		window.location.reload();
	};

	const handleWorkspaceCreated = (workspace: Workspace) => {
		setWorkspaces((prev) => [...prev, workspace]);
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
			{/* Top Navbar */}
			<Navbar
				user={user}
				onLogout={handleLogout}
				title='Dashboard'
			/>

			<div className='flex flex-1'>
				<Sidebar />

				{/* Main Content */}
				<div className='flex-1'>
					{/* Content Area - Empty for now */}
					<main className='p-6'>
						<div className='text-center py-12'>
							<div className='text-6xl mb-4'>🎵</div>
							<h2 className='text-xl font-semibold text-white mb-2'>
								Welcome to WubHub
							</h2>
							<p className='text-dark-400 mb-6 max-w-md mx-auto'>
								Select a workspace from the sidebar to get started, or create a
								new one to begin your music collaboration journey.
							</p>
						</div>
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
