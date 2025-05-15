import axios from 'axios';

// Change this line to use Vite's environment variable syntax
const API_URL = import.meta.env.VITE_API_URL || '/api/v1';

// Create axios instance with default configuration
const api = axios.create({
	baseURL: API_URL,
	headers: {
		'Content-Type': 'application/json',
		Accept: 'application/json',
	},
});

// Add a request interceptor to automatically include the auth token
api.interceptors.request.use(
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
api.interceptors.response.use(
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

export default api;
