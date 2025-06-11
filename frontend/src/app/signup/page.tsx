// src/app/signup/page.tsx
'use client';

import { registerUser } from '@/lib/api';
import { useState } from 'react';

export default function SignupPage() {
	const [formData, setFormData] = useState({
		email: '',
		username: '',
		password: '',
		password_confirmation: '',
	});
	const [errors, setErrors] = useState<string[]>([]);
	const [isLoading, setIsLoading] = useState(false);
	const [success, setSuccess] = useState(false);

	const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
		setFormData((prev) => ({
			...prev,
			[e.target.name]: e.target.value,
		}));
	};

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		setIsLoading(true);
		setErrors([]);

		const result = await registerUser(formData);

		if (result.success) {
			setSuccess(true);
			console.log('Registration successful:', result.data);
		} else {
			setErrors(result.errors || ['Registration failed']);
		}

		setIsLoading(false);
	};

	if (success) {
		return (
			<div
				className='min-h-screen flex items-center justify-center'
				style={{ backgroundColor: '#1a1a1a' }}
			>
				<div className='w-full max-w-sm px-6'>
					{/* Logo */}
					<div className='text-center mb-8'>
						<div className='inline-flex items-center gap-2 mb-6'>
							<div className='text-3xl'>🎵</div>
							<span className='text-2xl font-bold text-white'>wubhub</span>
						</div>
					</div>

					{/* Success Message */}
					<div className='text-center'>
						<div className='text-4xl mb-4'>🎉</div>
						<h1 className='text-2xl font-bold text-white mb-4'>
							Welcome to WubHub!
						</h1>
						<p
							className='mb-6'
							style={{ color: '#cccccc' }}
						>
							Your account has been created successfully. Ready to start
							collaborating on music?
						</p>
						<a
							href='/login'
							className='w-full inline-block py-3 px-4 rounded-md font-medium text-white transition-colors cursor-pointer text-center'
							style={{
								backgroundColor: '#00d4ff',
								color: '#1a1a1a',
							}}
						>
							Go to Login
						</a>
					</div>
				</div>
			</div>
		);
	}

	return (
		<div
			className='min-h-screen flex items-center justify-center'
			style={{ backgroundColor: '#1a1a1a' }}
		>
			<div className='w-full max-w-sm px-6'>
				{/* Title */}
				<h1 className='text-xl font-medium text-white text-center mb-8'>
					Create your account
				</h1>

				{/* Social Login Buttons */}
				<div className='space-y-3 mb-6'>
					<button
						type='button'
						className='w-full flex items-center justify-center gap-3 px-4 py-3 border border-gray-600 rounded-md text-white bg-transparent hover:bg-gray-800 transition-colors cursor-pointer'
					>
						<svg
							className='w-5 h-5'
							viewBox='0 0 24 24'
						>
							<path
								fill='currentColor'
								d='M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z'
							/>
							<path
								fill='currentColor'
								d='M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z'
							/>
							<path
								fill='currentColor'
								d='M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z'
							/>
							<path
								fill='currentColor'
								d='M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z'
							/>
						</svg>
						Continue with Google
					</button>

					<button
						type='button'
						className='w-full flex items-center justify-center gap-3 px-4 py-3 border border-gray-600 rounded-md text-white bg-transparent hover:bg-gray-800 transition-colors cursor-pointer'
					>
						<svg
							className='w-5 h-5'
							viewBox='0 0 24 24'
							fill='currentColor'
						>
							<path d='M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z' />
						</svg>
						Continue with Apple
					</button>

					<button
						type='button'
						className='w-full flex items-center justify-center gap-3 px-4 py-3 border border-gray-600 rounded-md text-white bg-transparent hover:bg-gray-800 transition-colors cursor-pointer'
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
						Continue with Facebook
					</button>
				</div>

				{/* Divider */}
				<div className='relative my-6'>
					<div className='absolute inset-0 flex items-center'>
						<div className='w-full border-t border-gray-600'></div>
					</div>
					<div className='relative flex justify-center text-sm'>
						<span
							className='px-2 text-gray-400'
							style={{ backgroundColor: '#1a1a1a' }}
						>
							OR
						</span>
					</div>
				</div>

				{/* Error Messages */}
				{errors.length > 0 && (
					<div
						className='mb-4 p-3 rounded-md'
						style={{
							backgroundColor: 'rgba(239, 68, 68, 0.1)',
							border: '1px solid #ef4444',
						}}
					>
						<div className='text-sm text-red-400'>
							{errors.map((error, index) => (
								<div key={index}>• {error}</div>
							))}
						</div>
					</div>
				)}

				{/* Form */}
				<form
					onSubmit={handleSubmit}
					className='space-y-4'
				>
					<div>
						<label
							htmlFor='username'
							className='block text-sm font-medium mb-2'
							style={{ color: '#00d4ff' }}
						>
							Username*
						</label>
						<input
							type='text'
							id='username'
							name='username'
							required
							value={formData.username}
							onChange={handleChange}
							className='w-full px-3 py-3 border border-gray-600 rounded-md text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent'
							style={{ backgroundColor: '#2d2d2d' }}
							placeholder='Choose a username'
						/>
					</div>

					<div>
						<label
							htmlFor='email'
							className='block text-sm font-medium mb-2'
							style={{ color: '#00d4ff' }}
						>
							Email address*
						</label>
						<input
							type='email'
							id='email'
							name='email'
							required
							value={formData.email}
							onChange={handleChange}
							className='w-full px-3 py-3 border border-gray-600 rounded-md text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent'
							style={{ backgroundColor: '#2d2d2d' }}
							placeholder='your@email.com'
							autoComplete='email'
						/>
					</div>

					<div>
						<label
							htmlFor='password'
							className='block text-sm font-medium mb-2'
							style={{ color: '#00d4ff' }}
						>
							Password*
						</label>
						<input
							type='password'
							id='password'
							name='password'
							required
							value={formData.password}
							onChange={handleChange}
							className='w-full px-3 py-3 border border-gray-600 rounded-md text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent'
							style={{ backgroundColor: '#2d2d2d' }}
							placeholder='Create a password'
							autoComplete='new-password'
						/>
					</div>

					<div>
						<label
							htmlFor='password_confirmation'
							className='block text-sm font-medium mb-2'
							style={{ color: '#00d4ff' }}
						>
							Confirm Password*
						</label>
						<input
							type='password'
							id='password_confirmation'
							name='password_confirmation'
							required
							value={formData.password_confirmation}
							onChange={handleChange}
							className='w-full px-3 py-3 border border-gray-600 rounded-md text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent'
							style={{ backgroundColor: '#2d2d2d' }}
							placeholder='Confirm your password'
							autoComplete='new-password'
						/>
					</div>

					{/* Submit Button - Splice Style */}
					<button
						type='submit'
						disabled={isLoading}
						className='w-full py-3 px-4 rounded-md font-medium text-white transition-colors disabled:opacity-50 cursor-pointer disabled:cursor-not-allowed'
						style={{
							backgroundColor: '#00d4ff',
							color: '#1a1a1a',
						}}
					>
						{isLoading ? 'Creating Account...' : 'Create Account'}
					</button>
				</form>

				{/* Sign In Link */}
				<div className='mt-6 text-center'>
					<span className='text-gray-400'>Already have an account? </span>
					<a
						href='/login'
						className='hover:underline cursor-pointer'
						style={{ color: '#00d4ff' }}
					>
						Sign in
					</a>
				</div>

				{/* Terms */}
				<div className='mt-8 text-center text-xs text-gray-500'>
					By continuing, you agree to WubHub's{' '}
					<a
						href='/terms'
						className='hover:underline cursor-pointer'
						style={{ color: '#00d4ff' }}
					>
						Terms of Use
					</a>{' '}
					and{' '}
					<a
						href='/privacy'
						className='hover:underline cursor-pointer'
						style={{ color: '#00d4ff' }}
					>
						Privacy Policy
					</a>
					.
				</div>
			</div>
		</div>
	);
}
