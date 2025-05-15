import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

const RegisterPage = () => {
	const navigate = useNavigate();
	const { registerUser } = useAuth();

	const [formData, setFormData] = useState({
		username: '',
		name: '',
		email: '',
		password: '',
		password_confirmation: '',
	});
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState('');

	const handleChange = (e) => {
		const { name, value } = e.target;
		setFormData((prev) => ({ ...prev, [name]: value }));
	};

	const validateForm = () => {
		if (!formData.username || !formData.email || !formData.password) {
			setError('All required fields must be filled');
			return false;
		}

		if (formData.password !== formData.password_confirmation) {
			setError('Passwords do not match');
			return false;
		}

		if (formData.password.length < 6) {
			setError('Password must be at least 6 characters');
			return false;
		}

		return true;
	};

	const handleSubmit = async (e) => {
		e.preventDefault();

		if (!validateForm()) return;

		try {
			setLoading(true);
			setError('');
			await registerUser(formData);
			navigate('/dashboard');
		} catch (err) {
			console.error('Registration error:', err);
			setError(err.message || 'Registration failed. Please try again.');
		} finally {
			setLoading(false);
		}
	};

	return (
		<div className='min-h-screen flex items-center justify-center bg-ableton-dark-400 px-4 py-10'>
			<div className='w-full max-w-md'>
				{/* Logo */}
				<div className='flex items-center justify-center mb-8'>
					<h1 className='text-4xl font-bold text-white tracking-tight'>
						WubHub
						<span className='text-ableton-blue-500'>.</span>
					</h1>
				</div>

				{/* Card */}
				<div className='bg-ableton-dark-300 rounded-xl shadow-2xl overflow-hidden'>
					{/* Header */}
					<div className='px-8 pt-8 pb-4'>
						<h2 className='text-2xl font-bold text-white mb-2'>
							Create Account
						</h2>
						<p className='text-gray-400 text-sm'>
							Join the platform for music collaboration and version control
						</p>
					</div>

					{/* Form */}
					<div className='px-8 pb-8'>
						{error && (
							<div className='mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-md text-red-500 text-sm'>
								{error}
							</div>
						)}

						<form
							onSubmit={handleSubmit}
							className='space-y-4'
						>
							<div>
								<label
									htmlFor='username'
									className='block text-sm text-gray-400 mb-1.5'
								>
									Username <span className='text-red-500'>*</span>
								</label>
								<input
									type='text'
									id='username'
									name='username'
									placeholder='coolmusician'
									className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
									value={formData.username}
									onChange={handleChange}
									required
								/>
							</div>

							<div>
								<label
									htmlFor='name'
									className='block text-sm text-gray-400 mb-1.5'
								>
									Full Name
								</label>
								<input
									type='text'
									id='name'
									name='name'
									placeholder='John Doe'
									className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
									value={formData.name}
									onChange={handleChange}
								/>
								<p className='mt-1 text-xs text-gray-500'>
									This will be displayed to other users
								</p>
							</div>

							<div>
								<label
									htmlFor='email'
									className='block text-sm text-gray-400 mb-1.5'
								>
									Email <span className='text-red-500'>*</span>
								</label>
								<input
									type='email'
									id='email'
									name='email'
									placeholder='your@email.com'
									className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
									value={formData.email}
									onChange={handleChange}
									required
								/>
							</div>

							<div>
								<label
									htmlFor='password'
									className='block text-sm text-gray-400 mb-1.5'
								>
									Password <span className='text-red-500'>*</span>
								</label>
								<input
									type='password'
									id='password'
									name='password'
									placeholder='••••••••'
									className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
									value={formData.password}
									onChange={handleChange}
									required
								/>
								<p className='mt-1 text-xs text-gray-500'>
									Minimum 6 characters
								</p>
							</div>

							<div>
								<label
									htmlFor='password_confirmation'
									className='block text-sm text-gray-400 mb-1.5'
								>
									Confirm Password <span className='text-red-500'>*</span>
								</label>
								<input
									type='password'
									id='password_confirmation'
									name='password_confirmation'
									placeholder='••••••••'
									className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
									value={formData.password_confirmation}
									onChange={handleChange}
									required
								/>
							</div>

							<div className='pt-2 mt-6'>
								<button
									type='submit'
									className='w-full bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white font-medium py-3 rounded-md transition-colors duration-200 flex justify-center items-center'
									disabled={loading}
								>
									{loading ? (
										<>
											<svg
												className='animate-spin -ml-1 mr-2 h-4 w-4 text-white'
												xmlns='http://www.w3.org/2000/svg'
												fill='none'
												viewBox='0 0 24 24'
											>
												<circle
													className='opacity-25'
													cx='12'
													cy='12'
													r='10'
													stroke='currentColor'
													strokeWidth='4'
												></circle>
												<path
													className='opacity-75'
													fill='currentColor'
													d='M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z'
												></path>
											</svg>
											Creating Account...
										</>
									) : (
										'Create Account'
									)}
								</button>
							</div>
						</form>

						<div className='mt-8 pt-6 border-t border-ableton-dark-100 text-center'>
							<p className='text-gray-400 text-sm'>
								Already have an account?{' '}
								<Link
									to='/login'
									className='text-ableton-blue-400 hover:text-ableton-blue-300 font-medium'
								>
									Sign in
								</Link>
							</p>
						</div>
					</div>
				</div>

				{/* Footer */}
				<div className='mt-8 text-center text-gray-500 text-xs'>
					&copy; {new Date().getFullYear()} WubHub - Version Control for
					Musicians
				</div>
			</div>
		</div>
	);
};

export default RegisterPage;
