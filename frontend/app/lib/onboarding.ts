import { api, ApiError } from './api';

// Types for onboarding API
export interface OnboardingStatus {
	needs_onboarding: boolean;
	current_step: 'not_started' | 'workspace_creation' | 'completed';
	completed_at?: string;
}

export interface CreateWorkspaceRequest {
	name: string;
	description?: string;
	workspace_type: 'project_based' | 'client_based' | 'library';
}

export interface WorkspaceResponse {
	id: string;
	name: string;
	description?: string;
	workspace_type: string;
	workspace_type_display: string;
	workspace_type_description: string;
	created_at: string;
}

export interface OnboardingWorkspaceResponse {
	message: string;
	workspace: WorkspaceResponse;
	current_step: string;
	onboarding_completed: boolean;
}

export interface OnboardingStartResponse {
	message: string;
	current_step: string;
}

export interface OnboardingCompleteResponse {
	message: string;
	completed_at: string;
}

/**
 * Onboarding Service Class
 * Handles all onboarding-related API calls
 */
class OnboardingService {
	/**
	 * Get current onboarding status
	 */
	async getStatus(): Promise<OnboardingStatus> {
		try {
			const response = await api.get<OnboardingStatus>('/onboarding/status');
			return response;
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Failed to get onboarding status.');
		}
	}

	/**
	 * Start onboarding process
	 */
	async start(): Promise<OnboardingStartResponse> {
		try {
			const response = await api.post<OnboardingStartResponse>(
				'/onboarding/start'
			);
			return response;
		} catch (error) {
			if (error instanceof ApiError) {
				// Handle specific start onboarding errors
				if (error.status === 422) {
					throw new ApiError(
						'Onboarding already completed. Please contact support if you need to restart.',
						error.status,
						error.errors
					);
				}
				throw error;
			}
			throw new ApiError('Failed to start onboarding process.');
		}
	}

	/**
	 * Create first workspace during onboarding
	 */
	async createFirstWorkspace(
		workspaceData: CreateWorkspaceRequest
	): Promise<OnboardingWorkspaceResponse> {
		try {
			const response = await api.post<OnboardingWorkspaceResponse>(
				'/onboarding/create_first_workspace',
				{ workspace: workspaceData }
			);
			return response;
		} catch (error) {
			if (error instanceof ApiError) {
				// Handle specific workspace creation errors
				if (error.status === 422) {
					throw new ApiError(
						'Invalid workspace information. Please check your input and try again.',
						error.status,
						error.errors
					);
				}
				throw error;
			}
			throw new ApiError('Failed to create workspace.');
		}
	}

	/**
	 * Complete onboarding process
	 */
	async complete(): Promise<OnboardingCompleteResponse> {
		try {
			const response = await api.post<OnboardingCompleteResponse>(
				'/onboarding/complete'
			);
			return response;
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Failed to complete onboarding.');
		}
	}

	/**
	 * Reset onboarding (for admin/support use)
	 */
	async reset(): Promise<OnboardingStartResponse> {
		try {
			const response = await api.post<OnboardingStartResponse>(
				'/onboarding/reset'
			);
			return response;
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Failed to reset onboarding.');
		}
	}
}

// Create and export onboarding service instance
export const onboardingService = new OnboardingService();
