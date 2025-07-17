'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '../hooks/useAuth';
import { motion } from 'framer-motion';

export default function OnboardingLayout({
	children,
}: {
	children: React.ReactNode;
}) {
	const { isAuthenticated, isLoading } = useAuth();
	const router = useRouter();

	// Redirect unauthenticated users to login
	useEffect(() => {
		if (!isLoading && !isAuthenticated) {
			console.log(
				'🔒 Unauthenticated user trying to access onboarding, redirecting to login...'
			);
			router.push('/auth/login');
		}
	}, [isAuthenticated, isLoading, router]);

	// Show loading state while checking authentication
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
					<p className='text-gray-400 mt-4'>Loading...</p>
				</motion.div>
			</div>
		);
	}

	// Don't render if not authenticated (will redirect)
	if (!isAuthenticated) {
		return null;
	}

	// Render onboarding content for authenticated users
	return <div className='min-h-screen bg-gray-900'>{children}</div>;
}
