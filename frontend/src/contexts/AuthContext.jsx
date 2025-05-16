// frontend/src/contexts/AuthContext.jsx
import React, { createContext, useState, useContext, useEffect } from 'react';
import api from '../services/api';

const AuthContext = createContext(null);

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
	const [currentUser, setCurrentUser] = useState(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);

	useEffect(() => {
		const token = localStorage.getItem('token');

		if (token) {
			getCurrentUser()
				.then((data) => {
					setCurrentUser(data.user);
					setLoading(false);
				})
				.catch((err) => {
					console.error('Failed to fetch user:', err);
					localStorage.removeItem('token');
					setLoading(false);
				});
		} else {
			setLoading(false);
		}
	}, []);

	const loginUser = async (email, password) => {
		try {
			setLoading(true);
			setError(null);
			// Use the loginUser function from the api object
			const response = await api.loginUser(email, password);
			localStorage.setItem('token', response.data.token);
			setCurrentUser(response.data.user);
			return response.data;
		} catch (err) {
			console.error('Login error:', err);
			setError(err.response?.data?.error || 'Invalid credentials');
			throw new Error(err.response?.data?.error || 'Failed to login');
		} finally {
			setLoading(false);
		}
	};

	const registerUser = async (userData) => {
		try {
			setLoading(true);
			setError(null);
			// Use the registerUser function from the api object
			const response = await api.registerUser(userData);
			localStorage.setItem('token', response.data.token);
			setCurrentUser(response.data.user);
			return response.data;
		} catch (err) {
			console.error('Registration error:', err);
			setError(err.response?.data?.errors?.join(', ') || 'Registration failed');
			throw new Error(
				err.response?.data?.errors?.join(', ') || 'Failed to register'
			);
		} finally {
			setLoading(false);
		}
	};

	const logout = () => {
		localStorage.removeItem('token');
		setCurrentUser(null);
	};

	const getCurrentUser = async () => {
		try {
			// Use the getCurrentUser function from the api object
			const response = await api.getCurrentUser();
			return response.data;
		} catch (error) {
			throw new Error('Failed to fetch current user');
		}
	};

	const value = {
		currentUser,
		isAuthenticated: !!currentUser,
		loading,
		error,
		loginUser,
		registerUser,
		logout,
		getCurrentUser,
	};

	return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
