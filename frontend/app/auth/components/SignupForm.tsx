// app/auth/components/SignupForm.tsx
'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useForm } from 'react-hook-form';
import { useAuth } from '../../hooks/useAuth';
import { useRouter } from 'next/navigation';
import ExternalAuthButtons from './ExternalAuthButtons';

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

	const { register: registerUser } = useAuth();
	const router = useRouter();

	const {
		register,
		handleSubmit,
		watch,
		formState: { errors, isValid },
	} = useForm<SignupFormData>({
		mode: 'onChange',
	});

	const password = watch('password');

	const containerVariants = {
		hidden: { opacity: 0 },
		visible: {
			opacity: 1,
			transition: {
				staggerChildren: 0.08,
				delayChildren: 0.03,
			},
		},
	};

	const itemVariants = {
		hidden: {
			opacity: 0,
			y: 15,
			scale: 0.97,
		},
		visible: {
			opacity: 1,
			y: 0,
			scale: 1,
			transition: {
				duration: 0.3,
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

			await registerUser(
				data.name,
				data.email,
				data.password,
				data.password_confirmation
			);

			console.log('✅ Registration completed successfully');
			console.log('🏠 About to redirect to dashboard...');

			router.push('/dashboard');

			console.log('✅ Router.push called');
		} catch (error: any) {
			console.error('❌ Signup error details:', {
				message: error.message,
				status: error.status,
				errors: error.errors,
				stack: error.stack,
			});

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

	return (
		<motion.div
			className='space-y-4'
			variants={containerVariants}
			initial='hidden'
			animate='visible'
		>
			{/* External Auth Buttons */}
			<motion.div variants={itemVariants}>
				<ExternalAuthButtons
					mode='signup'
					onError={setError}
					disabled={isLoading}
				/>
			</motion.div>

			{/* Divider */}
			<motion.div
				className='relative py-2'
				variants={itemVariants}
			>
				<div className='absolute inset-0 flex items-center'>
					<div className='w-full border-t border-gray-700'></div>
				</div>
				<div className='relative flex justify-center text-xs'>
					<span className='px-3 bg-gray-900 text-gray-400 font-medium'>OR</span>
				</div>
			</motion.div>

			{/* Signup Form */}
			<motion.form
				onSubmit={handleSubmit(onSubmit)}
				className='space-y-3'
				variants={itemVariants}
			>
				{/* Error Message */}
				<AnimatePresence>
					{error && (
						<motion.div
							className='bg-red-500/10 border border-red-500 rounded-lg p-2.5'
							initial={{ opacity: 0, height: 0 }}
							animate={{ opacity: 1, height: 'auto' }}
							exit={{ opacity: 0, height: 0 }}
							transition={{ duration: 0.25 }}
						>
							<p className='text-red-400 text-xs'>{error}</p>
						</motion.div>
					)}
				</AnimatePresence>

				{/* Name Field */}
				<div className='space-y-1'>
					<label className='block text-xs font-medium text-gray-300 mb-1'>
						Your Name*
					</label>
					<motion.input
						type='text'
						className={`w-full h-11 px-3.5 text-sm text-white bg-gray-800 border border-gray-600 rounded-lg focus:outline-none focus:border-blue-500 focus:ring-0 placeholder-gray-500 transition-all duration-200 ${
							errors.name ? 'border-red-500 focus:border-red-500' : ''
						}`}
						placeholder='Enter your name'
						whileFocus={{ scale: 1.008 }}
						transition={{ duration: 0.1 }}
						{...register('name', {
							required: 'Name is required',
							minLength: {
								value: 2,
								message: 'Name must be at least 2 characters',
							},
						})}
					/>
					<AnimatePresence>
						{errors.name && (
							<motion.p
								className='text-red-400 text-xs mt-0.5'
								initial={{ opacity: 0, height: 0 }}
								animate={{ opacity: 1, height: 'auto' }}
								exit={{ opacity: 0, height: 0 }}
								transition={{ duration: 0.15 }}
							>
								{errors.name.message}
							</motion.p>
						)}
					</AnimatePresence>
				</div>

				{/* Email Field */}
				<div className='space-y-1'>
					<label className='block text-xs font-medium text-blue-400 mb-1'>
						Email address*
					</label>
					<motion.input
						type='email'
						className={`w-full h-11 px-3.5 text-sm text-white bg-gray-800 border border-gray-600 rounded-lg focus:outline-none focus:border-blue-500 focus:ring-0 placeholder-gray-500 transition-all duration-200 ${
							errors.email ? 'border-red-500 focus:border-red-500' : ''
						}`}
						placeholder='Enter your email'
						whileFocus={{ scale: 1.008 }}
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
								className='text-red-400 text-xs mt-0.5'
								initial={{ opacity: 0, height: 0 }}
								animate={{ opacity: 1, height: 'auto' }}
								exit={{ opacity: 0, height: 0 }}
								transition={{ duration: 0.15 }}
							>
								{errors.email.message}
							</motion.p>
						)}
					</AnimatePresence>
				</div>

				{/* Password Field */}
				<div className='space-y-1'>
					<label className='block text-xs font-medium text-gray-300 mb-1'>
						Password*
					</label>
					<div className='relative'>
						<motion.input
							type={showPassword ? 'text' : 'password'}
							className={`w-full h-11 px-3.5 pr-10 text-sm text-white bg-gray-800 border border-gray-600 rounded-lg focus:outline-none focus:border-blue-500 focus:ring-0 placeholder-gray-500 transition-all duration-200 ${
								errors.password ? 'border-red-500 focus:border-red-500' : ''
							}`}
							placeholder='Create a password'
							whileFocus={{ scale: 1.008 }}
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
							className='absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-300 transition-colors focus:outline-none'
							type='button'
							onClick={() => setShowPassword(!showPassword)}
							whileHover={{ scale: 1.08 }}
							whileTap={{ scale: 0.92 }}
						>
							{showPassword ? (
								<svg
									className='w-4 h-4'
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
									className='w-4 h-4'
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
								className='text-red-400 text-xs mt-0.5'
								initial={{ opacity: 0, height: 0 }}
								animate={{ opacity: 1, height: 'auto' }}
								exit={{ opacity: 0, height: 0 }}
								transition={{ duration: 0.15 }}
							>
								{errors.password.message}
							</motion.p>
						)}
					</AnimatePresence>
				</div>

				{/* Confirm Password Field */}
				<div className='space-y-1'>
					<label className='block text-xs font-medium text-gray-300 mb-1'>
						Confirm password*
					</label>
					<div className='relative'>
						<motion.input
							type={showPasswordConfirmation ? 'text' : 'password'}
							className={`w-full h-11 px-3.5 pr-10 text-sm text-white bg-gray-800 border border-gray-600 rounded-lg focus:outline-none focus:border-blue-500 focus:ring-0 placeholder-gray-500 transition-all duration-200 ${
								errors.password_confirmation
									? 'border-red-500 focus:border-red-500'
									: ''
							}`}
							placeholder='Confirm your password'
							whileFocus={{ scale: 1.008 }}
							transition={{ duration: 0.1 }}
							{...register('password_confirmation', {
								required: 'Password confirmation is required',
								validate: (value) =>
									value === password || 'Passwords do not match',
							})}
						/>
						<motion.button
							className='absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-300 transition-colors focus:outline-none'
							type='button'
							onClick={() =>
								setShowPasswordConfirmation(!showPasswordConfirmation)
							}
							whileHover={{ scale: 1.08 }}
							whileTap={{ scale: 0.92 }}
						>
							{showPasswordConfirmation ? (
								<svg
									className='w-4 h-4'
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
									className='w-4 h-4'
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
								className='text-red-400 text-xs mt-0.5'
								initial={{ opacity: 0, height: 0 }}
								animate={{ opacity: 1, height: 'auto' }}
								exit={{ opacity: 0, height: 0 }}
								transition={{ duration: 0.15 }}
							>
								{errors.password_confirmation.message}
							</motion.p>
						)}
					</AnimatePresence>
				</div>

				{/* Submit Button */}
				<motion.button
					type='submit'
					disabled={!isValid || isLoading}
					className='w-full h-11 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800 disabled:cursor-not-allowed text-white font-semibold text-sm rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 flex items-center justify-center gap-2.5 mt-4'
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
								className='flex items-center gap-2.5'
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
