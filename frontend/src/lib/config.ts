export const config = {
	// API Configuration
	apiUrl: process.env.NEXT_PUBLIC_API_URL,

	// App Configuration
	appName: process.env.NEXT_PUBLIC_APP_NAME,
	environment: process.env.NEXT_PUBLIC_ENVIRONMENT,

	// Feature Flags
	isDevelopment: process.env.NEXT_PUBLIC_ENVIRONMENT === 'development',
	isProduction: process.env.NEXT_PUBLIC_ENVIRONMENT === 'production',

	// Authentication (for future use)
	auth: {
		googleClientId: process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID,
		facebookAppId: process.env.NEXT_PUBLIC_FACEBOOK_APP_ID,
	},

	// Storage Keys
	storage: {
		tokenKey: 'wubhub_token',
		userKey: 'wubhub_user',
	},

	// API Endpoints (relative to apiUrl)
	endpoints: {
		auth: {
			login: '/auth/login',
			register: '/auth/register',
			current: '/auth/current',
		},
		workspaces: '/workspaces',
		users: '/users',
		debug: '/debug',
	},
} as const;

// Export commonly used values for convenience
export const API_BASE = config.apiUrl;
export const APP_NAME = config.appName;
