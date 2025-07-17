// app/dashboard/page.tsx
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '../hooks/useAuth';
import { useOnboardingStatus, useOnboarding } from '../hooks/useOnboarding';
import { motion, AnimatePresence } from 'framer-motion';

// Onboarding Retrigger Button Component (for development)
function OnboardingRetriggerButton() {
	const { checkStatus, error, clearError } = useOnboarding();
	const [isResetting, setIsResetting] = useState(false);
	const router = useRouter();

	const handleRetriggerOnboarding = async () => {
		try {
			setIsResetting(true);
			clearError();

			// Import and use the onboarding service reset method
			const { onboardingService } = await import('../lib/onboarding');
			await onboardingService.reset();

			// Refresh onboarding status
			await checkStatus();

			console.log('✅ Onboarding reset successfully');

			// Redirect to onboarding
			router.push('/onboarding');
		} catch (error: any) {
			console.error('❌ Failed to reset onboarding:', error);
		} finally {
			setIsResetting(false);
		}
	};

	return (
		<div className='flex flex-col items-end gap-2'>
			<motion.button
				onClick={handleRetriggerOnboarding}
				disabled={isResetting}
				className='px-3 py-1 bg-yellow-600 hover:bg-yellow-700 disabled:bg-yellow-800 text-white text-xs rounded font-medium transition-colors'
				whileHover={{ scale: 1.05 }}
				whileTap={{ scale: 0.95 }}
			>
				{isResetting ? 'Resetting...' : 'Reset Onboarding'}
			</motion.button>

			<AnimatePresence>
				{error && (
					<motion.p
						className='text-xs text-red-400'
						initial={{ opacity: 0, y: -10 }}
						animate={{ opacity: 1, y: 0 }}
						exit={{ opacity: 0, y: -10 }}
					>
						{error}
					</motion.p>
				)}
			</AnimatePresence>
		</div>
	);
}

export default function DashboardPage() {
	const { user, logout } = useAuth();
	const { needsOnboarding, isCompleted, isLoading } = useOnboardingStatus();
	const router = useRouter();

	// Check onboarding status and redirect if needed
	useEffect(() => {
		if (!isLoading && needsOnboarding && !isCompleted) {
			console.log('🔄 User needs onboarding, redirecting...');
			router.push('/onboarding');
		}
	}, [needsOnboarding, isCompleted, isLoading, router]);

	// Show loading state while checking onboarding
	if (isLoading) {
		return (
			<div className='min-h-screen bg-gray-900 flex items-center justify-center'>
				<motion.div
					className='text-center'
					initial={{ opacity: 0, y: 20 }}
					animate={{ opacity: 1, y: 0 }}
					transition={{ duration: 0.5 }}
				>
					<motion.div
						className='w-16 h-16 bg-gradient-to-br from-purple-500 to-blue-600 rounded-xl flex items-center justify-center mx-auto mb-4'
						animate={{
							scale: [1, 1.1, 1],
							rotate: [0, 5, -5, 0],
						}}
						transition={{
							duration: 2,
							repeat: Infinity,
							ease: 'easeInOut',
						}}
					>
						<span className='text-white text-3xl font-bold'>W</span>
					</motion.div>
					<motion.div
						className='w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full mx-auto'
						animate={{ rotate: 360 }}
						transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
					/>
					<p className='text-gray-400 mt-4'>Setting up your workspace...</p>
				</motion.div>
			</div>
		);
	}

	// Don't render dashboard if user needs onboarding (will redirect)
	if (needsOnboarding && !isCompleted) {
		return null;
	}

	// Render dashboard for completed onboarding
	return (
		<div className='min-h-screen bg-gray-900 p-8'>
			<motion.div
				className='max-w-6xl mx-auto'
				initial={{ opacity: 0, y: 20 }}
				animate={{ opacity: 1, y: 0 }}
				transition={{ duration: 0.5 }}
			>
				{/* Header */}
				<div className='flex justify-between items-center mb-8'>
					<div>
						<h1 className='text-3xl font-bold text-white'>
							Welcome back, {user?.name}!
						</h1>
						<p className='text-gray-400 mt-2'>
							Ready to organize your music projects?
						</p>
					</div>

					<motion.button
						onClick={logout}
						className='px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors'
						whileHover={{ scale: 1.05 }}
						whileTap={{ scale: 0.95 }}
					>
						Logout
					</motion.button>
				</div>

				{/* Dashboard Content */}
				<div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6'>
					<motion.div
						className='bg-gray-800 rounded-xl p-6 border border-gray-700'
						whileHover={{ scale: 1.02 }}
						transition={{ duration: 0.2 }}
					>
						<h3 className='text-xl font-semibold text-white mb-2'>
							Your Projects
						</h3>
						<p className='text-gray-400'>
							Manage your music projects and collaborations
						</p>
					</motion.div>

					<motion.div
						className='bg-gray-800 rounded-xl p-6 border border-gray-700'
						whileHover={{ scale: 1.02 }}
						transition={{ duration: 0.2 }}
					>
						<h3 className='text-xl font-semibold text-white mb-2'>
							Recent Activity
						</h3>
						<p className='text-gray-400'>
							Stay updated with your latest musical activities
						</p>
					</motion.div>

					<motion.div
						className='bg-gray-800 rounded-xl p-6 border border-gray-700'
						whileHover={{ scale: 1.02 }}
						transition={{ duration: 0.2 }}
					>
						<h3 className='text-xl font-semibold text-white mb-2'>Settings</h3>
						<p className='text-gray-400'>Customize your WubHub experience</p>
					</motion.div>
				</div>

				{/* Debug Info (remove in production) */}
				{process.env.NODE_ENV === 'development' && (
					<motion.div
						className='mt-8 p-4 bg-gray-800 rounded-lg border border-gray-700'
						initial={{ opacity: 0 }}
						animate={{ opacity: 1 }}
						transition={{ delay: 0.5 }}
					>
						<div className='flex justify-between items-start mb-4'>
							<div>
								<h4 className='text-sm font-medium text-gray-300 mb-2'>
									Debug Info (Development Only)
								</h4>
								<div className='text-xs text-gray-400 space-y-1'>
									<p>User: {user?.email}</p>
									<p>
										Onboarding Status:{' '}
										{isCompleted ? 'Completed' : 'Not Completed'}
									</p>
									<p>Needs Onboarding: {needsOnboarding ? 'Yes' : 'No'}</p>
								</div>
							</div>
							<OnboardingRetriggerButton />
						</div>
					</motion.div>
				)}
			</motion.div>
		</div>
	);
}
