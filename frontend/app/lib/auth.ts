// app/lib/auth.ts
import { api, ApiError, AuthResponse } from './api';

// Request/Response Types
export interface LoginRequest {
	email: string;
	password: string;
}

export interface RegisterRequest {
	name: string;
	email: string;
	password: string;
	password_confirmation: string;
}

export interface User {
	id: string;
	email: string;
	name: string;
}

// Authentication Service Class
class AuthService {
	/**
	 * Login user with email and password
	 */
	async login(credentials: LoginRequest): Promise<AuthResponse> {
		try {
			const response = await api.postPublic<AuthResponse>(
				'/auth/login',
				credentials
			);
			return response;
		} catch (error) {
			if (error instanceof ApiError) {
				// Re-throw API errors with better context
				throw new ApiError(
					error.message || 'Login failed. Please check your credentials.',
					error.status,
					error.errors
				);
			}
			throw new ApiError('Login failed. Please try again.');
		}
	}

	/**
	 * Register new user
	 */
	async register(userData: RegisterRequest): Promise<AuthResponse> {
		try {
			console.log(
				'🔧 Auth Service: About to POST to /auth/register with:',
				userData
			);
			const response = await api.postPublic<AuthResponse>(
				'/auth/register',
				userData
			);
			console.log('🔧 Auth Service: Received response:', response);
			return response;
		} catch (error) {
			console.error('🔧 Auth Service: Registration error:', error);
			if (error instanceof ApiError) {
				// Handle specific registration errors
				if (error.status === 422) {
					throw new ApiError(
						'Registration failed. Please check your information.',
						error.status,
						error.errors
					);
				}
				throw error;
			}
			throw new ApiError('Registration failed. Please try again.');
		}
	}

	/**
	 * Get current user profile
	 */
	async getCurrentUser(): Promise<User> {
		try {
			const response = await api.get<{ user: User }>('/auth/me');
			return response.user;
		} catch (error) {
			if (error instanceof ApiError && error.status === 401) {
				throw new ApiError('Session expired. Please login again.', 401);
			}
			throw new ApiError('Failed to get user information.');
		}
	}

	/**
	 * Logout user (invalidate token on server)
	 */
	async logout(): Promise<void> {
		try {
			await api.post('/auth/logout');
		} catch (error) {
			// Logout should always succeed on client even if server fails
			console.warn('Server logout failed:', error);
		}
	}

	/**
	 * Refresh authentication token
	 */
	async refreshToken(): Promise<AuthResponse> {
		try {
			const response = await api.post<AuthResponse>('/auth/refresh');
			return response;
		} catch (error) {
			throw new ApiError('Session expired. Please login again.', 401);
		}
	}

	/**
	 * Request password reset
	 */
	async requestPasswordReset(email: string): Promise<void> {
		try {
			await api.postPublic('/auth/forgot-password', { email });
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Failed to send password reset email.');
		}
	}

	/**
	 * Reset password with token
	 */
	async resetPassword(
		token: string,
		password: string,
		passwordConfirmation: string
	): Promise<void> {
		try {
			await api.postPublic('/auth/reset-password', {
				token,
				password,
				password_confirmation: passwordConfirmation,
			});
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Failed to reset password.');
		}
	}

	/**
	 * Validate token (check if still valid)
	 */
	async validateToken(): Promise<boolean> {
		try {
			await this.getCurrentUser();
			return true;
		} catch (error) {
			return false;
		}
	}

	/**
	 * Sign in with Google
	 */
	async signInWithGoogle(): Promise<AuthResponse> {
		try {
			console.log('🔧 Auth Service: Starting Google sign-in...');

			// Import Google auth service
			const { googleAuthService } = await import('./googleAuth');

			// Get Google token
			const token = await googleAuthService.signInWithPopup();
			console.log('🔧 Auth Service: Received Google token');

			// Send to backend (changed from id_token to token)
			const response = await api.postPublic<AuthResponse>('/auth/google', {
				id_token: token, // Backend still expects 'id_token' parameter
			});

			console.log('🔧 Auth Service: Backend response:', response);
			return response;
		} catch (error) {
			console.error('🔧 Auth Service: Google sign-in error:', error);
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Google sign-in failed. Please try again.');
		}
	}
}

// Create and export auth service instance
export const authService = new AuthService();
