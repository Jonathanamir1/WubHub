export interface User {
	id: number;
	username: string;
	email: string;
	bio?: string;
	profile_image_url?: string;
	created_at: string;
}

export interface Workspace {
	id: number;
	name: string;
	description?: string;
	created_at: string;
	updated_at: string;
	user_id: number;
	project_count?: number;
}

export interface Container {
	id: number;
	workspace_id: number;
	parent_container_id?: number;
	name: string;
	container_type: string;
	template_level: number;
	metadata?: any;
	created_at: string;
	updated_at: string;
}

export interface TrackContent {
	id: number;
	container_id: number;
	user_id: number;
	title: string;
	description?: string;
	content_type?: string;
	text_content?: string;
	metadata?: any;
	tags?: string[];
	created_at: string;
	updated_at: string;
}

// API Response types
export interface AuthResponse {
	user: User;
	token: string;
}

export interface ApiError {
	error?: string;
	errors?: string[];
}

// src/lib/api.ts (updated version)
import { User, Workspace, AuthResponse, ApiError } from './types';
import { config } from './config';

export async function testAPI() {
	try {
		const response = await fetch(`${config.apiUrl}${config.endpoints.debug}`);
		const data = await response.json();
		return { success: true, data };
	} catch (error) {
		return { success: false, error: String(error) };
	}
}

export async function registerUser(userData: {
	email: string;
	username: string;
	password: string;
	password_confirmation: string;
}): Promise<
	{ success: true; data: AuthResponse } | { success: false; errors: string[] }
> {
	try {
		const response = await fetch(
			`${config.apiUrl}${config.endpoints.auth.register}`,
			{
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify(userData),
			}
		);

		const data = await response.json();

		if (response.ok) {
			return { success: true, data };
		} else {
			return { success: false, errors: data.errors || ['Registration failed'] };
		}
	} catch (error) {
		return { success: false, errors: ['Network error'] };
	}
}

export async function loginUser(credentials: {
	email: string;
	password: string;
}): Promise<
	{ success: true; data: AuthResponse } | { success: false; error: string }
> {
	try {
		const response = await fetch(
			`${config.apiUrl}${config.endpoints.auth.login}`,
			{
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify(credentials),
			}
		);

		const data = await response.json();

		if (response.ok) {
			return { success: true, data };
		} else {
			return { success: false, error: data.error || 'Login failed' };
		}
	} catch (error) {
		return { success: false, error: 'Network error' };
	}
}

export async function fetchWorkspaces(token: string): Promise<Workspace[]> {
	const response = await fetch(
		`${config.apiUrl}${config.endpoints.workspaces}`,
		{
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json',
			},
		}
	);

	if (!response.ok) {
		throw new Error(`HTTP ${response.status}`);
	}

	return response.json();
}

export async function createWorkspace(
	token: string,
	workspace: { name: string; description: string }
): Promise<Workspace> {
	const response = await fetch(
		`${config.apiUrl}${config.endpoints.workspaces}`,
		{
			method: 'POST',
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({ workspace }),
		}
	);

	if (!response.ok) {
		throw new Error(`HTTP ${response.status}`);
	}

	return response.json();
}

// Helper functions for local storage
export const storage = {
	getToken: (): string | null => {
		if (typeof window !== 'undefined') {
			return localStorage.getItem(config.storage.tokenKey);
		}
		return null;
	},

	setToken: (token: string): void => {
		if (typeof window !== 'undefined') {
			localStorage.setItem(config.storage.tokenKey, token);
		}
	},

	getUser: (): User | null => {
		if (typeof window !== 'undefined') {
			const userData = localStorage.getItem(config.storage.userKey);
			return userData ? JSON.parse(userData) : null;
		}
		return null;
	},

	setUser: (user: User): void => {
		if (typeof window !== 'undefined') {
			localStorage.setItem(config.storage.userKey, JSON.stringify(user));
		}
	},

	clear: (): void => {
		if (typeof window !== 'undefined') {
			localStorage.removeItem(config.storage.tokenKey);
			localStorage.removeItem(config.storage.userKey);
		}
	},
};
