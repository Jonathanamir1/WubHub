// src/lib/api.tsx - Updated to use environment variables with fallback
const API_BASE =
	process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1';

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
		console.log('API_BASE:', API_BASE); // Debug log
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

export async function fetchWorkspaces(token: string) {
	try {
		const response = await fetch(`${API_BASE}/workspaces`, {
			method: 'GET',
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json',
			},
		});

		if (response.ok) {
			const data = await response.json();
			return { success: true, data };
		} else if (response.status === 401) {
			return { success: false, error: 'Unauthorized', status: 401 };
		} else {
			return { success: false, error: 'Failed to fetch workspaces' };
		}
	} catch (error) {
		return { success: false, error: 'Network error' };
	}
}

export async function createWorkspace(
	token: string,
	workspaceData: {
		name: string;
		description: string;
		metadata?: any;
	}
) {
	try {
		const response = await fetch(`${API_BASE}/workspaces`, {
			method: 'POST',
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({ workspace: workspaceData }),
		});

		if (response.ok) {
			const data = await response.json();
			return { success: true, data };
		} else if (response.status === 401) {
			return { success: false, error: 'Unauthorized', status: 401 };
		} else {
			const errorData = await response.json();
			return {
				success: false,
				error: errorData.error || 'Failed to create workspace',
			};
		}
	} catch (error) {
		return { success: false, error: 'Network error' };
	}
}

export async function deleteWorkspace(token: string, workspaceId: number) {
	try {
		const response = await fetch(`${API_BASE}/workspaces/${workspaceId}`, {
			method: 'DELETE',
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json',
			},
		});

		if (response.ok) {
			return { success: true };
		} else if (response.status === 401) {
			return { success: false, error: 'Unauthorized', status: 401 };
		} else if (response.status === 404) {
			return { success: false, error: 'Workspace not found', status: 404 };
		} else {
			const errorData = await response.json();
			return {
				success: false,
				error: errorData.error || 'Failed to delete workspace',
			};
		}
	} catch (error) {
		return { success: false, error: 'Network error' };
	}
}

// Onboarding API functions
export async function getOnboardingStatus(token: string) {
	try {
		const response = await fetch(`${API_BASE}/onboarding/status`, {
			method: 'GET',
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json',
			},
		});

		if (response.ok) {
			const data = await response.json();
			return { success: true, data };
		} else if (response.status === 401) {
			return { success: false, error: 'Unauthorized', status: 401 };
		} else {
			return { success: false, error: 'Failed to get onboarding status' };
		}
	} catch (error) {
		return { success: false, error: 'Network error' };
	}
}

export async function startOnboarding(token: string) {
	try {
		const response = await fetch(`${API_BASE}/onboarding/start`, {
			method: 'POST',
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json',
			},
		});

		if (response.ok) {
			const data = await response.json();
			return { success: true, data };
		} else {
			return { success: false, error: 'Failed to start onboarding' };
		}
	} catch (error) {
		return { success: false, error: 'Network error' };
	}
}

export async function completeOnboarding(token: string) {
	try {
		const response = await fetch(`${API_BASE}/onboarding/complete`, {
			method: 'POST',
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json',
			},
		});

		if (response.ok) {
			const data = await response.json();
			return { success: true, data };
		} else {
			return { success: false, error: 'Failed to complete onboarding' };
		}
	} catch (error) {
		return { success: false, error: 'Network error' };
	}
}

export async function skipOnboarding(token: string) {
	try {
		const response = await fetch(`${API_BASE}/onboarding/skip`, {
			method: 'POST',
			headers: {
				Authorization: `Bearer ${token}`,
				'Content-Type': 'application/json',
			},
		});

		if (response.ok) {
			const data = await response.json();
			return { success: true, data };
		} else {
			return { success: false, error: 'Failed to skip onboarding' };
		}
	} catch (error) {
		return { success: false, error: 'Network error' };
	}
}
