const API_BASE = 'http://localhost:3000/api/v1';

export async function testAPI() {
	try {
		const response = await fetch(`${API_BASE}/debug`);
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
}) {
	try {
		const response = await fetch(`${API_BASE}/auth/register`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
			},
			body: JSON.stringify(userData),
		});

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
}) {
	try {
		const response = await fetch(`${API_BASE}/auth/login`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
			},
			body: JSON.stringify(credentials),
		});

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
