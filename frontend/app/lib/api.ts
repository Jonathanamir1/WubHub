// app/lib/api.ts
import Cookies from 'js-cookie';

// API Configuration
const API_BASE_URL =
	process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1';

// API Response Types
export interface ApiResponse<T = any> {
	success: boolean;
	data?: T;
	error?: string;
	errors?: string[];
}

export interface AuthResponse {
	user: {
		id: string;
		email: string;
		name: string;
	};
	token: string;
}

// Custom API Error Class
export class ApiError extends Error {
	public status: number;
	public errors: string[];

	constructor(message: string, status: number = 500, errors: string[] = []) {
		super(message);
		this.name = 'ApiError';
		this.status = status;
		this.errors = errors;
	}
}

// Base API Client
class ApiClient {
	private baseURL: string;

	constructor(baseURL: string) {
		this.baseURL = baseURL;
	}

	// Get auth token from cookies
	private getAuthToken(): string | null {
		return Cookies.get('auth_token') || null;
	}

	// Build request headers
	private getHeaders(includeAuth = true): HeadersInit {
		const headers: HeadersInit = {
			'Content-Type': 'application/json',
			Accept: 'application/json',
		};

		if (includeAuth) {
			const token = this.getAuthToken();
			if (token) {
				headers.Authorization = `Bearer ${token}`;
			}
		}

		return headers;
	}

	// Handle API responses
	private async handleResponse<T>(response: Response): Promise<T> {
		const contentType = response.headers.get('content-type');
		const isJson = contentType?.includes('application/json');

		if (!response.ok) {
			let errorMessage = `HTTP ${response.status}: ${response.statusText}`;
			let errors: string[] = [];

			if (isJson) {
				try {
					const errorData = await response.json();
					errorMessage = errorData.error || errorData.message || errorMessage;
					errors = errorData.errors || [];
				} catch (parseError) {
					console.error('Failed to parse error response:', parseError);
				}
			}

			throw new ApiError(errorMessage, response.status, errors);
		}

		if (isJson) {
			return await response.json();
		}

		// Return empty object for non-JSON responses
		return {} as T;
	}

	// Generic request method
	private async request<T>(
		endpoint: string,
		options: RequestInit = {}
	): Promise<T> {
		const url = `${this.baseURL}${endpoint}`;

		const config: RequestInit = {
			...options,
			headers: {
				...this.getHeaders(),
				...options.headers,
			},
		};

		try {
			const response = await fetch(url, config);
			return await this.handleResponse<T>(response);
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}

			// Network or other errors
			console.error('API Request failed:', error);
			throw new ApiError(
				'Network error. Please check your connection and try again.',
				0
			);
		}
	}

	// HTTP Methods
	async get<T>(endpoint: string): Promise<T> {
		return this.request<T>(endpoint, { method: 'GET' });
	}

	async post<T>(endpoint: string, data?: any): Promise<T> {
		return this.request<T>(endpoint, {
			method: 'POST',
			body: data ? JSON.stringify(data) : undefined,
		});
	}

	async put<T>(endpoint: string, data?: any): Promise<T> {
		return this.request<T>(endpoint, {
			method: 'PUT',
			body: data ? JSON.stringify(data) : undefined,
		});
	}

	async patch<T>(endpoint: string, data?: any): Promise<T> {
		return this.request<T>(endpoint, {
			method: 'PATCH',
			body: data ? JSON.stringify(data) : undefined,
		});
	}

	async delete<T>(endpoint: string): Promise<T> {
		return this.request<T>(endpoint, { method: 'DELETE' });
	}

	// Auth-specific methods (no token required)
	async postPublic<T>(endpoint: string, data?: any): Promise<T> {
		const url = `${this.baseURL}${endpoint}`;

		const config: RequestInit = {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				Accept: 'application/json',
			},
			body: data ? JSON.stringify(data) : undefined,
		};

		const response = await fetch(url, config);
		return await this.handleResponse<T>(response);
	}
}

// Create and export API client instance
export const api = new ApiClient(API_BASE_URL);
