// frontend/src/services/api.js
import axios from 'axios';

// Get base API URL from environment variables - without the /api/v1 suffix
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

// Create axios instance with default configuration
const axiosInstance = axios.create({
	baseURL: API_URL,
	headers: {
		'Content-Type': 'application/json',
		Accept: 'application/json',
	},
});

// Add a request interceptor to automatically include the auth token
axiosInstance.interceptors.request.use(
	(config) => {
		const token = localStorage.getItem('token');
		if (token) {
			config.headers.Authorization = `Bearer ${token}`;
		}
		return config;
	},
	(error) => Promise.reject(error)
);

// Add a response interceptor to handle common errors
axiosInstance.interceptors.response.use(
	(response) => response,
	(error) => {
		const { response } = error;

		if (response) {
			// If unauthorized, clear token and redirect to login
			if (response.status === 401) {
				localStorage.removeItem('token');
				window.location.href = '/login';
			}

			// Handle validation errors
			if (response.status === 422) {
				return Promise.reject({
					...error,
					message: response.data.errors?.join(', ') || 'Validation failed',
				});
			}
		}

		return Promise.reject(error);
	}
);

// Auth API endpoints
const loginUser = (email, password) => {
	return axiosInstance.post('/api/v1/auth/login', { email, password });
};

const registerUser = (userData) => {
	return axiosInstance.post('/api/v1/auth/register', userData);
};

const getCurrentUser = () => {
	return axiosInstance.get('/api/v1/auth/current');
};

// User API endpoints
const getUser = (id) => {
	return axiosInstance.get(`/api/v1/users/${id}`);
};

const updateUser = (id, userData) => {
	return axiosInstance.put(`/api/v1/users/${id}`, { user: userData });
};

const updateUserAvatar = (id, file) => {
	const formData = new FormData();
	formData.append('user[avatar]', file);

	return axiosInstance.put(`/api/v1/users/${id}`, formData, {
		headers: {
			'Content-Type': 'multipart/form-data',
		},
	});
};

// Workspace API endpoints
const getWorkspaces = () => {
	return axiosInstance.get('/api/v1/workspaces');
};

const getWorkspace = (id) => {
	return axiosInstance.get(`/api/v1/workspaces/${id}`);
};

const createWorkspace = (workspaceData) => {
	return axiosInstance.post('/api/v1/workspaces', { workspace: workspaceData });
};

const updateWorkspace = (id, workspaceData) => {
	return axiosInstance.put(`/api/v1/workspaces/${id}`, {
		workspace: workspaceData,
	});
};

const deleteWorkspace = (id) => {
	return axiosInstance.delete(`/api/v1/workspaces/${id}`);
};

// Workspace preferences endpoints
const getWorkspacePreferences = () => {
	return axiosInstance.get('/api/v1/workspace_preferences');
};

const updateWorkspaceOrder = (workspaceIds) => {
	return axiosInstance.put('/api/v1/workspace_preferences/update_order', {
		workspace_ids: workspaceIds,
	});
};

const updateFavoriteWorkspaces = (workspaceIds) => {
	return axiosInstance.put('/api/v1/workspace_preferences/update_favorites', {
		workspace_ids: workspaceIds,
	});
};

const updatePrivateWorkspaces = (workspaceIds) => {
	return axiosInstance.put('/api/v1/workspace_preferences/update_privacy', {
		workspace_ids: workspaceIds,
	});
};

const updateCollapsedSections = (collapsedSections) => {
	return axiosInstance.put(
		'/api/v1/workspace_preferences/update_collapsed_sections',
		{
			collapsed_sections: collapsedSections,
		}
	);
};

// Project API endpoints
const getProjects = (workspaceId) => {
	return axiosInstance.get(`/api/v1/workspaces/${workspaceId}/projects`);
};

const getRecentProjects = () => {
	return axiosInstance.get('/api/v1/projects/recent');
};

const getProject = (workspaceId, projectId) => {
	// Use the standalone project endpoint instead of the nested one
	return axiosInstance.get(`/api/v1/projects/${projectId}`);
};

const createProject = (workspaceId, projectData) => {
	return axiosInstance.post(`/api/v1/workspaces/${workspaceId}/projects`, {
		project: projectData,
	});
};

const updateProject = (workspaceId, projectId, projectData) => {
	return axiosInstance.put(
		`/api/v1/workspaces/${workspaceId}/projects/${projectId}`,
		{
			project: projectData,
		}
	);
};

const deleteProject = (workspaceId, projectId) => {
	return axiosInstance.delete(
		`/api/v1/workspaces/${workspaceId}/projects/${projectId}`
	);
};

// Track Version API endpoints
const getTrackVersions = (projectId) => {
	return axiosInstance.get(`/api/v1/projects/${projectId}/track_versions`);
};

const getTrackVersion = (versionId) => {
	return axiosInstance.get(`/api/v1/track_versions/${versionId}`);
};

const createTrackVersion = (projectId, versionData) => {
	return axiosInstance.post(`/api/v1/projects/${projectId}/track_versions`, {
		track_version: versionData,
	});
};

const updateTrackVersion = (versionId, versionData) => {
	return axiosInstance.put(`/api/v1/track_versions/${versionId}`, {
		track_version: versionData,
	});
};

const deleteTrackVersion = (versionId) => {
	return axiosInstance.delete(`/api/v1/track_versions/${versionId}`);
};

// Track Content API endpoints
const getTrackContents = (versionId) => {
	return axiosInstance.get(
		`/api/v1/track_versions/${versionId}/track_contents`
	);
};

const getTrackContent = (contentId) => {
	return axiosInstance.get(`/api/v1/track_contents/${contentId}`);
};

const createTrackContent = (versionId, contentData, file) => {
	const formData = new FormData();

	// Append file if it exists
	if (file) {
		formData.append('file', file);
	}

	// Append track_content data
	Object.keys(contentData).forEach((key) => {
		if (key === 'metadata' && contentData[key]) {
			formData.append(
				`track_content[${key}]`,
				JSON.stringify(contentData[key])
			);
		} else if (contentData[key] !== undefined && contentData[key] !== null) {
			formData.append(`track_content[${key}]`, contentData[key]);
		}
	});

	return axiosInstance.post(
		`/api/v1/track_versions/${versionId}/track_contents`,
		formData,
		{
			headers: {
				'Content-Type': 'multipart/form-data',
			},
		}
	);
};

const updateTrackContent = (contentId, contentData) => {
	return axiosInstance.put(`/api/v1/track_contents/${contentId}`, {
		track_content: contentData,
	});
};

const deleteTrackContent = (contentId) => {
	return axiosInstance.delete(`/api/v1/track_contents/${contentId}`);
};

// Comment API endpoints
const getComments = (versionId) => {
	return axiosInstance.get(`/api/v1/track_versions/${versionId}/comments`);
};

const createComment = (versionId, commentData) => {
	return axiosInstance.post(`/api/v1/track_versions/${versionId}/comments`, {
		comment: commentData,
	});
};

const updateComment = (commentId, commentData) => {
	return axiosInstance.put(`/api/v1/comments/${commentId}`, {
		comment: commentData,
	});
};

const deleteComment = (commentId) => {
	return axiosInstance.delete(`/api/v1/comments/${commentId}`);
};

const getRoles = (projectId) => {
	return axiosInstance.get(`/api/v1/projects/${projectId}/roles`);
};

const createRole = (projectId, roleData) => {
	return axiosInstance.post(`/api/v1/projects/${projectId}/roles`, {
		role: roleData,
	});
};

const updateRole = (roleId, roleData) => {
	return axiosInstance.put(`/api/v1/roles/${roleId}`, {
		role: roleData,
	});
};

const deleteRole = (roleId) => {
	return axiosInstance.delete(`/api/v1/roles/${roleId}`);
};

// NEW: Folder API endpoints
const getRootFolders = (projectId) => {
	return axiosInstance.get(`/api/v1/projects/${projectId}/folders`);
};

const getFolder = (projectId, folderId) => {
	return axiosInstance.get(`/api/v1/projects/${projectId}/folders/${folderId}`);
};

const createFolder = (projectId, folderData) => {
	return axiosInstance.post(`/api/v1/projects/${projectId}/folders`, {
		folder: folderData,
	});
};

const updateFolder = (projectId, folderId, folderData) => {
	return axiosInstance.put(
		`/api/v1/projects/${projectId}/folders/${folderId}`,
		{
			folder: folderData,
		}
	);
};

const deleteFolder = (projectId, folderId) => {
	return axiosInstance.delete(
		`/api/v1/projects/${projectId}/folders/${folderId}`
	);
};

// NEW: Audio File API endpoints
const getAudioFiles = (projectId, folderId) => {
	return axiosInstance.get(
		`/api/v1/projects/${projectId}/folders/${folderId}/audio_files`
	);
};

const getAudioFile = (projectId, folderId, fileId) => {
	return axiosInstance.get(
		`/api/v1/projects/${projectId}/folders/${folderId}/audio_files/${fileId}`
	);
};

const createAudioFile = (projectId, folderId, formData, config = {}) => {
	return axiosInstance.post(
		`/api/v1/projects/${projectId}/folders/${folderId}/audio_files`,
		formData,
		{
			headers: {
				'Content-Type': 'multipart/form-data',
			},
			...config,
		}
	);
};

const deleteAudioFile = (projectId, folderId, fileId) => {
	return axiosInstance.delete(
		`/api/v1/projects/${projectId}/folders/${folderId}/audio_files/${fileId}`
	);
};

// Search API endpoints
const searchProjects = (query) => {
	return axiosInstance.get(
		`/api/v1/search/projects?q=${encodeURIComponent(query)}`
	);
};

const searchWorkspaces = (query) => {
	return axiosInstance.get(
		`/api/v1/search/workspaces?q=${encodeURIComponent(query)}`
	);
};

const searchUsers = (query) => {
	return axiosInstance.get(
		`/api/v1/search/users?q=${encodeURIComponent(query)}`
	);
};

// Download API endpoints
const getDownloadUrl = (contentId) => {
	return `${API_URL}/api/v1/download/track_content/${contentId}`;
};

const getAudioFileDownloadUrl = (fileId) => {
	return `${API_URL}/api/v1/download/audio_file/${fileId}`;
};

// Create API object with all functions
const api = {
	// Core axios instance for custom calls
	axiosInstance,

	// Auth endpoints
	loginUser,
	registerUser,
	getCurrentUser,

	// User endpoints
	getUser,
	updateUser,
	updateUserAvatar,

	// Workspace endpoints
	getWorkspaces,
	getWorkspace,
	createWorkspace,
	updateWorkspace,
	deleteWorkspace,

	// Workspace preferences endpoints
	getWorkspacePreferences,
	updateWorkspaceOrder,
	updateFavoriteWorkspaces,
	updatePrivateWorkspaces,
	updateCollapsedSections,

	// Project endpoints
	getProjects,
	getRecentProjects,
	getProject,
	createProject,
	updateProject,
	deleteProject,

	// Track Version endpoints
	getTrackVersions,
	getTrackVersion,
	createTrackVersion,
	updateTrackVersion,
	deleteTrackVersion,

	// Track Content endpoints
	getTrackContents,
	getTrackContent,
	createTrackContent,
	updateTrackContent,
	deleteTrackContent,

	// Comment endpoints
	getComments,
	createComment,
	updateComment,
	deleteComment,

	// Role (collaborator) endpoints
	getRoles,
	createRole,
	updateRole,
	deleteRole,

	// Folder endpoints
	getRootFolders,
	getFolder,
	createFolder,
	updateFolder,
	deleteFolder,

	// Audio File endpoints
	getAudioFiles,
	getAudioFile,
	createAudioFile,
	deleteAudioFile,

	// Search endpoints
	searchProjects,
	searchWorkspaces,
	searchUsers,

	// Download endpoints
	getDownloadUrl,
	getAudioFileDownloadUrl,
};

export default api;
