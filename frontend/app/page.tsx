// frontend/app/page.tsx

'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from './hooks/useAuth';
import { useOnboarding } from './hooks/useOnboarding';
import { motion } from 'framer-motion';
import Link from 'next/link';

export default function HomePage() {
	const { isLoading, isAuthenticated, user, logout } = useAuth();
	const { checkStatus, clearError } = useOnboarding();
	const router = useRouter();
	const [isResetting, setIsResetting] = useState(false);

	// For authenticated users, show the authenticated homepage
	if (isAuthenticated && user) {
		const handleRetriggerOnboarding = async () => {
			try {
				setIsResetting(true);
				clearError();

				// Import and use the onboarding service reset method
				const { onboardingService } = await import('./lib/onboarding');
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
			<div className='min-h-screen bg-gray-900'>
				<div className='max-w-4xl mx-auto px-4 py-16'>
					{/* Header */}
					<motion.div
						initial={{ opacity: 0, y: 20 }}
						animate={{ opacity: 1, y: 0 }}
						transition={{ duration: 0.8 }}
						className='text-center mb-12'
					>
						<motion.div
							className='w-24 h-24 bg-gradient-to-br from-purple-500 to-blue-600 rounded-xl flex items-center justify-center mx-auto mb-6'
							animate={{
								scale: [1, 1.05, 1],
								rotate: [0, 2, -2, 0],
							}}
							transition={{
								duration: 3,
								repeat: Infinity,
								ease: 'easeInOut',
							}}
						>
							<span className='text-white text-4xl font-bold'>W</span>
						</motion.div>

						<h1 className='text-5xl font-bold text-white mb-4'>
							Welcome back, {user.name}!
						</h1>
						<p className='text-xl text-gray-400'>
							Ready to organize your music projects?
						</p>
					</motion.div>

					{/* Action Cards */}
					<motion.div
						initial={{ opacity: 0, y: 30 }}
						animate={{ opacity: 1, y: 0 }}
						transition={{ duration: 0.8, delay: 0.2 }}
						className='grid md:grid-cols-2 gap-6 mb-12'
					>
						{/* Dashboard Card */}
						<motion.div
							whileHover={{ scale: 1.02 }}
							whileTap={{ scale: 0.98 }}
							className='bg-gray-800 border border-gray-700 rounded-xl p-6 cursor-pointer'
							onClick={() => router.push('/dashboard')}
						>
							<h3 className='text-xl font-semibold text-white mb-2'>
								Go to Dashboard
							</h3>
							<p className='text-gray-400 mb-4'>
								Access your workspaces and projects
							</p>
							<div className='text-blue-400 font-medium'>Open Dashboard →</div>
						</motion.div>

						{/* Onboarding Reset Card */}
						<motion.div
							whileHover={{ scale: 1.02 }}
							whileTap={{ scale: 0.98 }}
							className='bg-gray-800 border border-gray-700 rounded-xl p-6 cursor-pointer'
							onClick={handleRetriggerOnboarding}
						>
							<h3 className='text-xl font-semibold text-white mb-2'>
								Reset Onboarding
							</h3>
							<p className='text-gray-400 mb-4'>
								Start the setup process again
							</p>
							<div className='text-yellow-400 font-medium'>
								{isResetting ? 'Resetting...' : 'Reset Setup →'}
							</div>
						</motion.div>
					</motion.div>

					{/* Footer Actions */}
					<motion.div
						initial={{ opacity: 0 }}
						animate={{ opacity: 1 }}
						transition={{ duration: 0.8, delay: 0.4 }}
						className='flex justify-center'
					>
						<motion.button
							onClick={logout}
							whileHover={{ scale: 1.05 }}
							whileTap={{ scale: 0.95 }}
							className='px-6 py-3 bg-red-600 hover:bg-red-700 text-white font-medium rounded-lg transition-colors'
						>
							Sign Out
						</motion.button>
					</motion.div>
				</div>
			</div>
		);
	}

	// Loading state
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
					<p className='text-gray-400 mt-4'>Loading WubHub...</p>
				</motion.div>
			</div>
		);
	}

	// Unauthenticated users - show landing page
	return (
		<div className='min-h-screen bg-gray-900'>
			<div className='max-w-4xl mx-auto px-4 py-16 text-center'>
				<motion.div
					initial={{ opacity: 0, y: 20 }}
					animate={{ opacity: 1, y: 0 }}
					transition={{ duration: 0.8 }}
				>
					<motion.div
						className='w-24 h-24 bg-gradient-to-br from-purple-500 to-blue-600 rounded-xl flex items-center justify-center mx-auto mb-6'
						animate={{
							scale: [1, 1.05, 1],
							rotate: [0, 2, -2, 0],
						}}
						transition={{
							duration: 3,
							repeat: Infinity,
							ease: 'easeInOut',
						}}
					>
						<span className='text-white text-4xl font-bold'>W</span>
					</motion.div>

					<h1 className='text-5xl font-bold text-white mb-4'>
						Welcome to WubHub
					</h1>
					<p className='text-xl text-gray-400 mb-8'>
						The ultimate organizational tool for musicians
					</p>

					<div className='flex gap-4 justify-center'>
						<Link
							href='/auth/login'
							className='px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors'
						>
							Sign In
						</Link>
						<Link
							href='/auth/register'
							className='px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors'
						>
							Sign Up
						</Link>
					</div>
				</motion.div>
			</div>
		</div>
	);
}
