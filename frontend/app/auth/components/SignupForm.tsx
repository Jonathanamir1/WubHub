// app/auth/components/SignupForm.tsx
'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useForm } from 'react-hook-form';
import { useAuth } from '../../hooks/useAuth';
import { useRouter } from 'next/navigation';

interface SignupFormData {
	name: string;
	email: string;
	password: string;
	password_confirmation: string;
}

export default function SignupForm() {
	const [isLoading, setIsLoading] = useState(false);
	const [showPassword, setShowPassword] = useState(false);
	const [showPasswordConfirmation, setShowPasswordConfirmation] =
		useState(false);
	const [error, setError] = useState<string | null>(null);

	const { login } = useAuth();
	const router = useRouter();

	const {
		register,
		handleSubmit,
		watch,
		formState: { errors, isValid },
	} = useForm<SignupFormData>({
		mode: 'onChange',
	});

	// Watch password field for confirmation validation
	const password = watch('password');

	// Animation variants for staggered entrance within the form
	const containerVariants = {
		hidden: { opacity: 0 },
		visible: {
			opacity: 1,
			transition: {
				staggerChildren: 0.1,
				delayChildren: 0.05,
			},
		},
	};

	const itemVariants = {
		hidden: {
			opacity: 0,
			y: 20,
			scale: 0.95,
		},
		visible: {
			opacity: 1,
			y: 0,
			scale: 1,
			transition: {
				duration: 0.4,
				ease: [0.25, 0.46, 0.45, 0.94],
			},
		},
	};

	const onSubmit = async (data: SignupFormData) => {
		console.log('🚀 Signup form submitted with:', data);
		setIsLoading(true);
		setError(null);

		try {
			console.log('📝 About to call register function...');
			console.log('🔗 API URL:', process.env.NEXT_PUBLIC_API_URL);

			// Call register function from useAuth
			await register(
				data.name,
				data.email,
				data.password,
				data.password_confirmation
			);

			console.log('✅ Registration completed successfully');
			console.log('🏠 About to redirect to dashboard...');

			// Redirect to dashboard
			router.push('/dashboard');

			console.log('✅ Router.push called');
		} catch (error: any) {
			console.error('❌ Signup error details:', {
				message: error.message,
				status: error.status,
				errors: error.errors,
				stack: error.stack,
			});

			// Handle different error types
			if (error.status === 422) {
				setError(
					error.errors?.join(', ') ||
						'Please check your registration information.'
				);
			} else if (error.status === 0) {
				setError('Network error. Please check your connection.');
			} else {
				setError(error.message || 'Registration failed. Please try again.');
			}
		} finally {
			setIsLoading(false);
			console.log('🔄 Signup process completed (success or failure)');
		}
	};

	const handleGoogleSignup = () => {
		// TODO: Implement Google OAuth
		console.log('Google signup clicked');
	};

	const handleAppleSignup = () => {
		// TODO: Implement Apple OAuth
		console.log('Apple signup clicked');
	};

	const handleFacebookSignup = () => {
		// TODO: Implement Facebook OAuth
		console.log('Facebook signup clicked');
	};

	const buttonVariants = {
		idle: { scale: 1, transition: { duration: 0.1 } },
		hover: { scale: 1.02, transition: { duration: 0.1 } },
		tap: { scale: 0.98, transition: { duration: 0.1 } },
	};

	const LoadingSpinner = () => (
		<motion.div
			className='w-5 h-5 border-2 border-white border-t-transparent rounded-full'
			animate={{ rotate: 360 }}
			transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
		/>
	);

	return (
		<motion.div
			className='space-y-6'
			variants={containerVariants}
			initial='hidden'
			animate='visible'
		>
			{/* Social Signup Buttons */}
			<motion.div
				className='space-y-4'
				variants={itemVariants}
			>
				<motion.button
					onClick={handleGoogleSignup}
					className='w-full h-14 border border-gray-600 hover:border-gray-500 bg-gray-800 hover:bg-gray-750 text-white font-medium text-base rounded-xl flex items-center justify-center gap-3 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50'
					variants={buttonVariants}
					initial='idle'
					whileHover='hover'
					whileTap='tap'
				>
					<svg
						className='w-6 h-6'
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
					Continue with Google
				</motion.button>

				<motion.button
					onClick={handleAppleSignup}
					className='w-full h-14 border border-gray-600 hover:border-gray-500 bg-gray-800 hover:bg-gray-750 text-white font-medium text-base rounded-xl flex items-center justify-center gap-3 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50'
					variants={buttonVariants}
					initial='idle'
					whileHover='hover'
					whileTap='tap'
				>
					<svg
						className='w-6 h-6'
						viewBox='0 0 24 24'
					>
						<path
							fill='currentColor'
							d='M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z'
						/>
					</svg>
					Continue with Apple
				</motion.button>

				<motion.button
					onClick={handleFacebookSignup}
					className='w-full h-14 border border-gray-600 hover:border-gray-500 bg-gray-800 hover:bg-gray-750 text-white font-medium text-base rounded-xl flex items-center justify-center gap-3 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50'
					variants={buttonVariants}
					initial='idle'
					whileHover='hover'
					whileTap='tap'
				>
					<svg
						className='w-6 h-6'
						viewBox='0 0 24 24'
					>
						<path
							fill='currentColor'
							d='M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z'
						/>
					</svg>
					Continue with Facebook
				</motion.button>
			</motion.div>

			{/* Divider */}
			<motion.div
				className='relative'
				variants={itemVariants}
			>
				<div className='absolute inset-0 flex items-center'>
					<div className='w-full border-t border-gray-700'></div>
				</div>
				<div className='relative flex justify-center text-sm'>
					<span className='px-4 bg-gray-900 text-gray-400 font-medium'>OR</span>
				</div>
			</motion.div>

			{/* Signup Form */}
			<motion.form
				onSubmit={handleSubmit(onSubmit)}
				className='space-y-5'
				variants={itemVariants}
			>
				{/* Error Message */}
				<AnimatePresence>
					{error && (
						<motion.div
							className='bg-red-500/10 border border-red-500 rounded-lg p-3'
							initial={{ opacity: 0, height: 0 }}
							animate={{ opacity: 1, height: 'auto' }}
							exit={{ opacity: 0, height: 0 }}
							transition={{ duration: 0.3 }}
						>
							<p className='text-red-400 text-sm'>{error}</p>
						</motion.div>
					)}
				</AnimatePresence>

				<div className='space-y-1'>
					<label className='block text-sm font-medium text-blue-400 mb-2'>
						Email address*
					</label>
					<motion.input
						type='email'
						className={`w-full h-14 px-4 text-base text-white bg-gray-800 border border-gray-600 rounded-xl focus:outline-none focus:border-blue-500 focus:ring-0 placeholder-gray-500 transition-all duration-200 ${
							errors.email ? 'border-red-500 focus:border-red-500' : ''
						}`}
						placeholder='Enter your email'
						whileFocus={{ scale: 1.01 }}
						transition={{ duration: 0.1 }}
						{...register('email', {
							required: 'Email is required',
							pattern: {
								value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
								message: 'Invalid email address',
							},
						})}
					/>
					<AnimatePresence>
						{errors.email && (
							<motion.p
								className='text-red-400 text-sm mt-1'
								initial={{ opacity: 0, height: 0 }}
								animate={{ opacity: 1, height: 'auto' }}
								exit={{ opacity: 0, height: 0 }}
								transition={{ duration: 0.2 }}
							>
								{errors.email.message}
							</motion.p>
						)}
					</AnimatePresence>
				</div>

				<div className='space-y-1'>
					<label className='block text-sm font-medium text-gray-300 mb-2'>
						Password*
					</label>
					<div className='relative'>
						<motion.input
							type={showPassword ? 'text' : 'password'}
							className={`w-full h-14 px-4 pr-12 text-base text-white bg-gray-800 border border-gray-600 rounded-xl focus:outline-none focus:border-blue-500 focus:ring-0 placeholder-gray-500 transition-all duration-200 ${
								errors.password ? 'border-red-500 focus:border-red-500' : ''
							}`}
							placeholder='Create a password'
							whileFocus={{ scale: 1.01 }}
							transition={{ duration: 0.1 }}
							{...register('password', {
								required: 'Password is required',
								minLength: {
									value: 6,
									message: 'Password must be at least 6 characters',
								},
							})}
						/>
						<motion.button
							className='absolute right-4 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-300 transition-colors focus:outline-none'
							type='button'
							onClick={() => setShowPassword(!showPassword)}
							whileHover={{ scale: 1.1 }}
							whileTap={{ scale: 0.9 }}
						>
							{showPassword ? (
								<svg
									className='w-6 h-6'
									fill='none'
									stroke='currentColor'
									viewBox='0 0 24 24'
								>
									<path
										strokeLinecap='round'
										strokeLinejoin='round'
										strokeWidth={2}
										d='M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L8.464 8.464a1.5 1.5 0 00-2.12 0l-6.708 6.707a1.5 1.5 0 002.12 2.121l6.708-6.707a1.5 1.5 0 000-2.121z'
									/>
								</svg>
							) : (
								<svg
									className='w-6 h-6'
									fill='none'
									stroke='currentColor'
									viewBox='0 0 24 24'
								>
									<path
										strokeLinecap='round'
										strokeLinejoin='round'
										strokeWidth={2}
										d='M15 12a3 3 0 11-6 0 3 3 0 016 0z'
									/>
									<path
										strokeLinecap='round'
										strokeLinejoin='round'
										strokeWidth={2}
										d='M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z'
									/>
								</svg>
							)}
						</motion.button>
					</div>
					<AnimatePresence>
						{errors.password && (
							<motion.p
								className='text-red-400 text-sm mt-1'
								initial={{ opacity: 0, height: 0 }}
								animate={{ opacity: 1, height: 'auto' }}
								exit={{ opacity: 0, height: 0 }}
								transition={{ duration: 0.2 }}
							>
								{errors.password.message}
							</motion.p>
						)}
					</AnimatePresence>
				</div>

				<div className='space-y-1'>
					<label className='block text-sm font-medium text-gray-300 mb-2'>
						Confirm password*
					</label>
					<div className='relative'>
						<motion.input
							type={showPasswordConfirmation ? 'text' : 'password'}
							className={`w-full h-14 px-4 pr-12 text-base text-white bg-gray-800 border border-gray-600 rounded-xl focus:outline-none focus:border-blue-500 focus:ring-0 placeholder-gray-500 transition-all duration-200 ${
								errors.password_confirmation
									? 'border-red-500 focus:border-red-500'
									: ''
							}`}
							placeholder='Confirm your password'
							whileFocus={{ scale: 1.01 }}
							transition={{ duration: 0.1 }}
							{...register('password_confirmation', {
								required: 'Password confirmation is required',
								validate: (value) =>
									value === password || 'Passwords do not match',
							})}
						/>
						<motion.button
							className='absolute right-4 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-300 transition-colors focus:outline-none'
							type='button'
							onClick={() =>
								setShowPasswordConfirmation(!showPasswordConfirmation)
							}
							whileHover={{ scale: 1.1 }}
							whileTap={{ scale: 0.9 }}
						>
							{showPasswordConfirmation ? (
								<svg
									className='w-6 h-6'
									fill='none'
									stroke='currentColor'
									viewBox='0 0 24 24'
								>
									<path
										strokeLinecap='round'
										strokeLinejoin='round'
										strokeWidth={2}
										d='M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L8.464 8.464a1.5 1.5 0 00-2.12 0l-6.708 6.707a1.5 1.5 0 002.12 2.121l6.708-6.707a1.5 1.5 0 000-2.121z'
									/>
								</svg>
							) : (
								<svg
									className='w-6 h-6'
									fill='none'
									stroke='currentColor'
									viewBox='0 0 24 24'
								>
									<path
										strokeLinecap='round'
										strokeLinejoin='round'
										strokeWidth={2}
										d='M15 12a3 3 0 11-6 0 3 3 0 016 0z'
									/>
									<path
										strokeLinecap='round'
										strokeLinejoin='round'
										strokeWidth={2}
										d='M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z'
									/>
								</svg>
							)}
						</motion.button>
					</div>
					<AnimatePresence>
						{errors.password_confirmation && (
							<motion.p
								className='text-red-400 text-sm mt-1'
								initial={{ opacity: 0, height: 0 }}
								animate={{ opacity: 1, height: 'auto' }}
								exit={{ opacity: 0, height: 0 }}
								transition={{ duration: 0.2 }}
							>
								{errors.password_confirmation.message}
							</motion.p>
						)}
					</AnimatePresence>
				</div>

				<motion.button
					type='submit'
					disabled={!isValid || isLoading}
					className='w-full h-14 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800 disabled:cursor-not-allowed text-white font-semibold text-base rounded-xl transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 flex items-center justify-center gap-3'
					variants={buttonVariants}
					initial='idle'
					whileHover={!isLoading ? 'hover' : 'idle'}
					whileTap={!isLoading ? 'tap' : 'idle'}
				>
					<AnimatePresence mode='wait'>
						{isLoading ? (
							<motion.div
								key='loading'
								initial={{ opacity: 0 }}
								animate={{ opacity: 1 }}
								exit={{ opacity: 0 }}
								className='flex items-center gap-3'
							>
								<LoadingSpinner />
								<span>Creating account...</span>
							</motion.div>
						) : (
							<motion.span
								key='continue'
								initial={{ opacity: 0 }}
								animate={{ opacity: 1 }}
								exit={{ opacity: 0 }}
							>
								Create account
							</motion.span>
						)}
					</AnimatePresence>
				</motion.button>
			</motion.form>
		</motion.div>
	);
}
