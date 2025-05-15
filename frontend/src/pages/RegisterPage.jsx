import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import {
	TextInput,
	PasswordInput,
	Paper,
	Title,
	Container,
	Button,
	Text,
	Divider,
	Group,
	Alert,
} from '@mantine/core';
import { FiAlertCircle } from 'react-icons/fi';
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
			setError('All fields are required');
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
		<Container
			size='xs'
			py='xl'
		>
			<Paper
				radius='md'
				p='xl'
				withBorder
			>
				<Title
					order={2}
					align='center'
					mb='md'
				>
					Create your WubHub Account
				</Title>

				<Text
					color='dimmed'
					size='sm'
					align='center'
					mb='lg'
				>
					Join the platform for music collaboration and version control
				</Text>

				{error && (
					<Alert
						icon={<FiAlertCircle size={16} />}
						color='red'
						mb='md'
					>
						{error}
					</Alert>
				)}

				<form onSubmit={handleSubmit}>
					<TextInput
						label='Username'
						placeholder='coolmusician'
						required
						name='username'
						value={formData.username}
						onChange={handleChange}
						mb='md'
					/>

					<TextInput
						label='Full Name'
						placeholder='John Doe'
						name='name'
						value={formData.name}
						onChange={handleChange}
						mb='md'
					/>

					<TextInput
						label='Email'
						placeholder='your@email.com'
						required
						name='email'
						value={formData.email}
						onChange={handleChange}
						mb='md'
					/>

					<PasswordInput
						label='Password'
						placeholder='Your password'
						required
						name='password'
						value={formData.password}
						onChange={handleChange}
						mb='md'
					/>

					<PasswordInput
						label='Confirm Password'
						placeholder='Confirm your password'
						required
						name='password_confirmation'
						value={formData.password_confirmation}
						onChange={handleChange}
						mb='md'
					/>

					<Button
						fullWidth
						mt='xl'
						type='submit'
						loading={loading}
					>
						Create Account
					</Button>
				</form>

				<Divider
					label='Already have an account?'
					labelPosition='center'
					my='lg'
				/>

				<Button
					component={Link}
					to='/login'
					fullWidth
					variant='outline'
				>
					Log In
				</Button>
			</Paper>
		</Container>
	);
};

export default RegisterPage;
