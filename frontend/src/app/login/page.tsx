'use client';

import { loginUser } from '@/lib/api';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
	const router = useRouter();
	const [formData, setFormData] = useState({
		email: '',
		password: '',
	});
	const [error, setError] = useState('');
	const [isLoading, setIsLoading] = useState(false);

	// Check if already logged in
	useEffect(() => {
		const token = localStorage.getItem('wubhub_token');
		if (token) {
			router.push('/dashboard');
		}
	}, [router]);

	const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
		setFormData((prev) => ({
			...prev,
			[e.target.name]: e.target.value,
		}));
	};

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();
		setIsLoading(true);
		setError('');

		const result = await loginUser(formData);

		if (result.success) {
			console.log('Login successful:', result.data);
			localStorage.setItem('wubhub_token', result.data.token);
			localStorage.setItem('wubhub_user', JSON.stringify(result.data.user));
			router.push('/dashboard');
		} else {
			setError(result.error || 'Login failed');
		}

		setIsLoading(false);
	};

	return (
		<div
			className='min-h-screen flex items-center justify-center'
			style={{ backgroundColor: '#1a1a1a' }}
		>
			<div className='w-full max-w-sm px-6'>
				{/* Logo */}
				<div className='text-center mb-8'>
					<div className='inline-flex items-center gap-2 mb-6'>
						<span className='text-2xl font-bold text-white'>wubhub</span>
					</div>
				</div>

				{/* Title */}
				<h1 className='text-xl font-medium text-white text-center mb-8'>
					Log into your account
				</h1>

				{/* Social Login Buttons (Placeholder for now) */}
				<div className='space-y-3 mb-6'>
					<button
						type='button'
						className='w-full flex items-center justify-center gap-3 px-4 py-3 border border-gray-600 rounded-md text-white bg-transparent hover:bg-gray-800 transition-colors'
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
							<path d='M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701' />
						</svg>
						Continue with Apple
					</button>
					<button
						type='button'
						className='w-full flex items-center justify-center gap-3 px-4 py-3 border border-gray-600 rounded-md text-white bg-transparent hover:bg-gray-800 transition-colors'
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

				{/* Error Message */}
				{error && (
					<div
						className='mb-4 p-3 rounded-md'
						style={{
							backgroundColor: 'rgba(239, 68, 68, 0.1)',
							border: '1px solid #ef4444',
						}}
					>
						<div className='text-sm text-red-400'>{error}</div>
					</div>
				)}

				{/* Form */}
				<form
					onSubmit={handleSubmit}
					className='space-y-4'
				>
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
						<div className='relative'>
							<input
								type='password'
								id='password'
								name='password'
								required
								value={formData.password}
								onChange={handleChange}
								className='w-full px-3 py-3 border border-gray-600 rounded-md text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent'
								style={{ backgroundColor: '#2d2d2d' }}
								autoComplete='current-password'
							/>
							<button
								type='button'
								className='absolute inset-y-0 right-0 pr-3 flex items-center'
							>
								<svg
									className='h-5 w-5 text-gray-400'
									fill='none'
									viewBox='0 0 24 24'
									stroke='currentColor'
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
							</button>
						</div>
					</div>

					{/* Forgot Password */}
					<div className='text-left'>
						<a
							href='/forgot-password'
							className='text-sm hover:underline'
							style={{ color: '#00d4ff' }}
						>
							Forgot password?
						</a>
					</div>

					{/* Submit Button - Splice Style */}
					<button
						type='submit'
						disabled={isLoading}
						className='w-full py-3 px-4 rounded-md font-medium text-white transition-colors disabled:opacity-50'
						style={{
							backgroundColor: '#00d4ff',
							color: '#1a1a1a',
						}}
					>
						{isLoading ? 'Signing In...' : 'Continue'}
					</button>
				</form>

				{/* Sign Up Link */}
				<div className='mt-6 text-center'>
					<span className='text-gray-400'>Don't have an account? </span>
					<a
						href='/signup'
						className='hover:underline'
						style={{ color: '#00d4ff' }}
					>
						Sign up
					</a>
				</div>

				{/* Terms (Optional) */}
				<div className='mt-8 text-center text-xs text-gray-500'>
					By continuing, you agree to WubHub's{' '}
					<a
						href='/terms'
						className='hover:underline'
						style={{ color: '#00d4ff' }}
					>
						Terms of Use
					</a>{' '}
					and{' '}
					<a
						href='/privacy'
						className='hover:underline'
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
