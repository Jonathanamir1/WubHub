import { api, ApiError } from './api';

// Request/Response Types
export interface CreateWorkspaceRequest {
	name: string;
	description?: string;
	workspace_type: 'project_based' | 'client_based' | 'library';
}

export interface Workspace {
	id: string;
	name: string;
	description?: string;
	workspace_type: 'project_based' | 'client_based' | 'library';
	created_at: string;
	updated_at: string;
	user_id: string;
}

export interface WorkspaceResponse {
	id: string;
	name: string;
	description?: string;
	workspace_type: string;
	created_at: string;
	updated_at: string;
	user_id: string;
}

// Workspace type configuration
export const WORKSPACE_TYPES = {
	project_based: {
		id: 'project_based' as const,
		name: 'Project-Based',
		description: 'Organized by your music projects, albums, and creative work',
		icon: '🎵',
	},
	client_based: {
		id: 'client_based' as const,
		name: 'Client-Based',
		description: 'Organized by clients and their individual projects',
		icon: '👥',
	},
	library: {
		id: 'library' as const,
		name: 'Library',
		description:
			'Collection of samples, loops, references, and sound libraries',
		icon: '📚',
	},
} as const;

export type WorkspaceType = keyof typeof WORKSPACE_TYPES;

// Workspace Service Class
class WorkspaceService {
	/**
	 * Create a new workspace
	 */
	async create(workspaceData: CreateWorkspaceRequest): Promise<Workspace> {
		try {
			console.log(
				'🔧 Workspace Service: Creating workspace with:',
				workspaceData
			);

			const response = await api.post<WorkspaceResponse>('/workspaces', {
				workspace: workspaceData,
			});

			console.log(
				'🔧 Workspace Service: Workspace created successfully:',
				response
			);

			// Transform response to match our Workspace interface
			return {
				id: response.id,
				name: response.name,
				description: response.description,
				workspace_type: response.workspace_type as
					| 'project_based'
					| 'client_based'
					| 'library',
				created_at: response.created_at,
				updated_at: response.updated_at,
				user_id: response.user_id,
			};
		} catch (error) {
			console.error('🔧 Workspace Service: Creation error:', error);

			if (error instanceof ApiError) {
				// Handle specific workspace creation errors
				if (error.status === 422) {
					throw new ApiError(
						'Workspace creation failed. Please check your information.',
						error.status,
						error.errors
					);
				}
				throw error;
			}
			throw new ApiError('Failed to create workspace. Please try again.');
		}
	}

	/**
	 * Get all user workspaces
	 */
	async getAll(): Promise<Workspace[]> {
		try {
			const response = await api.get<WorkspaceResponse[]>('/workspaces');

			// Transform response array to match our Workspace interface
			return response.map((workspace) => ({
				id: workspace.id,
				name: workspace.name,
				description: workspace.description,
				workspace_type: workspace.workspace_type as
					| 'project_based'
					| 'client_based'
					| 'library',
				created_at: workspace.created_at,
				updated_at: workspace.updated_at,
				user_id: workspace.user_id,
			}));
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Failed to fetch workspaces.');
		}
	}

	/**
	 * Get a specific workspace by ID
	 */
	async getById(id: string): Promise<Workspace> {
		try {
			const response = await api.get<WorkspaceResponse>(`/workspaces/${id}`);

			return {
				id: response.id,
				name: response.name,
				description: response.description,
				workspace_type: response.workspace_type as
					| 'project_based'
					| 'client_based'
					| 'library',
				created_at: response.created_at,
				updated_at: response.updated_at,
				user_id: response.user_id,
			};
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Failed to fetch workspace.');
		}
	}

	/**
	 * Update a workspace
	 */
	async update(
		id: string,
		workspaceData: Partial<CreateWorkspaceRequest>
	): Promise<Workspace> {
		try {
			const response = await api.put<WorkspaceResponse>(`/workspaces/${id}`, {
				workspace: workspaceData,
			});

			return {
				id: response.id,
				name: response.name,
				description: response.description,
				workspace_type: response.workspace_type as
					| 'project_based'
					| 'client_based'
					| 'library',
				created_at: response.created_at,
				updated_at: response.updated_at,
				user_id: response.user_id,
			};
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Failed to update workspace.');
		}
	}

	/**
	 * Delete a workspace
	 */
	async delete(id: string): Promise<void> {
		try {
			await api.delete(`/workspaces/${id}`);
		} catch (error) {
			if (error instanceof ApiError) {
				throw error;
			}
			throw new ApiError('Failed to delete workspace.');
		}
	}
}

// Create and export workspace service instance
export const workspaceService = new WorkspaceService();
