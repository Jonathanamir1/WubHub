// app/auth/components/ExternalAuthButtons.tsx
'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '../../hooks/useAuth';
import { useRouter } from 'next/navigation';

interface ExternalAuthButtonsProps {
	mode: 'login' | 'signup';
	onError: (error: string) => void;
	disabled?: boolean;
}

export default function ExternalAuthButtons({
	mode,
	onError,
	disabled = false,
}: ExternalAuthButtonsProps) {
	const [isGoogleLoading, setIsGoogleLoading] = useState(false);
	const { signInWithGoogle } = useAuth();
	const router = useRouter();

	const buttonVariants = {
		idle: { scale: 1, transition: { duration: 0.1 } },
		hover: { scale: 1.015, transition: { duration: 0.1 } },
		tap: { scale: 0.985, transition: { duration: 0.1 } },
	};

	const LoadingSpinner = () => (
		<motion.div
			className='w-4 h-4 border-2 border-white border-t-transparent rounded-full'
			animate={{ rotate: 360 }}
			transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
		/>
	);

	const handleGoogleAuth = async () => {
		console.log(`🔐 Google ${mode} clicked`);
		setIsGoogleLoading(true);
		onError(''); // Clear any existing errors

		try {
			console.log('📝 About to call Google sign-in...');

			await signInWithGoogle();

			console.log('✅ Google sign-in completed successfully');
			console.log('🏠 About to redirect to dashboard...');

			router.push('/dashboard');

			console.log('✅ Router.push called');
		} catch (error: any) {
			console.error(`❌ Google ${mode} error:`, {
				message: error.message,
				status: error.status,
				errors: error.errors,
			});

			// Handle Google-specific errors
			if (error.message?.includes('popup')) {
				onError('Please allow popups for Google sign-in to work.');
			} else if (error.status === 401) {
				onError('Google authentication failed. Please try again.');
			} else {
				onError(error.message || `Google ${mode} failed. Please try again.`);
			}
		} finally {
			setIsGoogleLoading(false);
			console.log(`🔄 Google ${mode} process completed`);
		}
	};

	const handleAppleAuth = () => {
		console.log(`Apple ${mode} clicked`);
		onError('Apple sign-in coming soon!');
	};

	const handleFacebookAuth = () => {
		console.log(`Facebook ${mode} clicked`);
		onError('Facebook sign-in coming soon!');
	};

	const actionText = mode === 'login' ? 'Continue' : 'Continue';

	return (
		<div className='space-y-3'>
			{/* Google Button */}
			<motion.button
				onClick={handleGoogleAuth}
				disabled={isGoogleLoading || disabled}
				className='w-full h-11 border border-gray-600 hover:border-gray-500 bg-gray-800 hover:bg-gray-750 text-white font-medium text-sm rounded-lg flex items-center justify-center gap-2.5 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 disabled:opacity-50 disabled:cursor-not-allowed'
				variants={buttonVariants}
				initial='idle'
				whileHover={!isGoogleLoading && !disabled ? 'hover' : 'idle'}
				whileTap={!isGoogleLoading && !disabled ? 'tap' : 'idle'}
			>
				<AnimatePresence mode='wait'>
					{isGoogleLoading ? (
						<motion.div
							key='loading'
							initial={{ opacity: 0 }}
							animate={{ opacity: 1 }}
							exit={{ opacity: 0 }}
							className='flex items-center gap-2.5'
						>
							<LoadingSpinner />
							<span>Connecting to Google...</span>
						</motion.div>
					) : (
						<motion.div
							key='normal'
							initial={{ opacity: 0 }}
							animate={{ opacity: 1 }}
							exit={{ opacity: 0 }}
							className='flex items-center gap-2.5'
						>
							<svg
								className='w-5 h-5'
								viewBox='0 0 24 24'
							>
								<path
									fill='#4285F4'
									d='M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z'
								/>
								<path
									fill='#34A853'
									d='M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z'
								/>
								<path
									fill='#FBBC05'
									d='M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z'
								/>
								<path
									fill='#EA4335'
									d='M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z'
								/>
							</svg>
							<span>{actionText} with Google</span>
						</motion.div>
					)}
				</AnimatePresence>
			</motion.button>

			{/* Apple Button */}
			<motion.button
				onClick={handleAppleAuth}
				disabled={disabled}
				className='w-full h-11 border border-gray-600 hover:border-gray-500 bg-gray-800 hover:bg-gray-750 text-white font-medium text-sm rounded-lg flex items-center justify-center gap-2.5 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 opacity-50'
				variants={buttonVariants}
				initial='idle'
				whileHover={!disabled ? 'hover' : 'idle'}
				whileTap={!disabled ? 'tap' : 'idle'}
			>
				<svg
					className='w-5 h-5'
					viewBox='0 0 24 24'
				>
					<path
						fill='currentColor'
						d='M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z'
					/>
				</svg>
				{actionText} with Apple (Coming Soon)
			</motion.button>

			{/* Facebook Button */}
			<motion.button
				onClick={handleFacebookAuth}
				disabled={disabled}
				className='w-full h-11 border border-gray-600 hover:border-gray-500 bg-gray-800 hover:bg-gray-750 text-white font-medium text-sm rounded-lg flex items-center justify-center gap-2.5 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 opacity-50'
				variants={buttonVariants}
				initial='idle'
				whileHover={!disabled ? 'hover' : 'idle'}
				whileTap={!disabled ? 'tap' : 'idle'}
			>
				<svg
					className='w-5 h-5'
					viewBox='0 0 24 24'
				>
					<path
						fill='currentColor'
						d='M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z'
					/>
				</svg>
				{actionText} with Facebook (Coming Soon)
			</motion.button>
		</div>
	);
}
