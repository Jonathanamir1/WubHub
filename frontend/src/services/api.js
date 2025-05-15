import axios from 'axios';

// Change this line to use Vite's environment variable syntax
const API_URL = import.meta.env.VITE_API_URL || '/api/v1';

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

		if (response && response.status === 401) {
			// If unauthorized, clear token and redirect to login
			localStorage.removeItem('token');
			window.location.href = '/login';
		}

		return Promise.reject(error);
	}
);

// Auth API endpoints
const loginUser = (email, password) => {
	console.log('Login attempt with:', { email, password });
	return axiosInstance.post('/api/v1/auth/login', { email, password });
};

const registerUser = (userData) => {
	console.log('Register attempt with:', userData);
	return axiosInstance.post('/api/v1/auth/register', userData);
};

const getCurrentUser = () => {
	return axiosInstance.get('/api/v1/auth/current');
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

// Project API endpoints
const getProjects = (workspaceId) => {
	return axiosInstance.get(`/api/v1/workspaces/${workspaceId}/projects`);
};

const getRecentProjects = () => {
	return axiosInstance.get('/api/v1/projects/recent');
};

const getProject = (workspaceId, projectId) => {
	return axiosInstance.get(
		`/api/v1/workspaces/${workspaceId}/projects/${projectId}`
	);
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

const getTrackVersion = (projectId, versionId) => {
	return axiosInstance.get(
		`/api/v1/projects/${projectId}/track_versions/${versionId}`
	);
};

const createTrackVersion = (projectId, versionData) => {
	return axiosInstance.post(`/api/v1/projects/${projectId}/track_versions`, {
		track_version: versionData,
	});
};

const deleteTrackVersion = (projectId, versionId) => {
	return axiosInstance.delete(
		`/api/v1/projects/${projectId}/track_versions/${versionId}`
	);
};

// Create API object with all functions
const api = {
	// Core axios instance for custom calls
	axiosInstance,

	// Auth endpoints
	loginUser,
	registerUser,
	getCurrentUser,

	// Workspace endpoints
	getWorkspaces,
	getWorkspace,
	createWorkspace,
	updateWorkspace,
	deleteWorkspace,

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
	deleteTrackVersion,
};

export default api;
