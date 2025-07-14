// app/hooks/useAuth.ts
'use client';

import {
	useState,
	useEffect,
	useContext,
	createContext,
	createElement,
} from 'react';
import { ReactNode } from 'react';
import Cookies from 'js-cookie';
import { authService, User } from '../lib/auth';
import { ApiError } from '../lib/api';

interface AuthContextType {
	user: User | null;
	isLoading: boolean;
	isAuthenticated: boolean;
	login: (email: string, password: string) => Promise<void>;
	register: (
		name: string,
		email: string,
		password: string,
		passwordConfirmation: string
	) => Promise<void>;
	signInWithGoogle: () => Promise<void>;
	logout: () => Promise<void>;
	checkAuth: () => Promise<boolean>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
	children: ReactNode;
}

export function AuthProvider(props: AuthProviderProps) {
	const { children } = props;
	const [user, setUser] = useState<User | null>(null);
	const [isLoading, setIsLoading] = useState<boolean>(true);

	const isAuthenticated: boolean = !!user;

	const checkAuth = async (): Promise<boolean> => {
		setIsLoading(true);

		try {
			const token = Cookies.get('auth_token');

			if (!token) {
				setUser(null);
				setIsLoading(false);
				return false;
			}

			const userData = await authService.getCurrentUser();
			setUser(userData);
			setIsLoading(false);
			return true;
		} catch (error) {
			console.error('Auth check failed:', error);
			Cookies.remove('auth_token');
			setUser(null);
			setIsLoading(false);
			return false;
		}
	};

	const login = async (email: string, password: string): Promise<void> => {
		try {
			const response = await authService.login({ email, password });

			Cookies.set('auth_token', response.token, {
				expires: 7,
				secure: process.env.NODE_ENV === 'production',
				sameSite: 'lax',
			});

			setUser(response.user);
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new Error('Login failed. Please try again.');
		}
	};

	const register = async (
		name: string,
		email: string,
		password: string,
		passwordConfirmation: string
	): Promise<void> => {
		try {
			const response = await authService.register({
				name,
				email,
				password,
				password_confirmation: passwordConfirmation,
			});

			Cookies.set('auth_token', response.token, {
				expires: 7,
				secure: process.env.NODE_ENV === 'production',
				sameSite: 'lax',
			});

			setUser(response.user);
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new Error('Registration failed. Please try again.');
		}
	};

	const signInWithGoogle = async (): Promise<void> => {
		try {
			console.log('🔐 Starting Google sign-in...');
			const response = await authService.signInWithGoogle();

			Cookies.set('auth_token', response.token, {
				expires: 7,
				secure: process.env.NODE_ENV === 'production',
				sameSite: 'lax',
			});

			setUser(response.user);
			console.log('✅ Google sign-in successful');
		} catch (error) {
			console.error('❌ Google sign-in error:', error);
			if (error instanceof ApiError) {
				throw error;
			}
			throw new Error('Google sign-in failed. Please try again.');
		}
	};

	const logout = async (): Promise<void> => {
		try {
			await authService.logout();
		} catch (error) {
			console.warn('Server logout failed:', error);
		} finally {
			// Import Google auth service and sign out
			import('../lib/googleAuth')
				.then(({ googleAuthService }) => {
					googleAuthService.signOut();
				})
				.catch(() => {
					// Ignore Google sign-out errors
				});

			Cookies.remove('auth_token');
			setUser(null);
			window.location.href = '/auth/login';
		}
	};

	// Check authentication on mount
	useEffect(() => {
		checkAuth();
	}, []);

	const contextValue: AuthContextType = {
		user,
		isLoading,
		isAuthenticated,
		login,
		register,
		signInWithGoogle,
		logout,
		checkAuth,
	};

	return createElement(AuthContext.Provider, { value: contextValue }, children);
}

export function useAuth(): AuthContextType {
	const context = useContext(AuthContext);

	if (context === undefined) {
		throw new Error('useAuth must be used within an AuthProvider');
	}

	return context;
}
