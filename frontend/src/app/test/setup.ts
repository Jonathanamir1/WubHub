// Place this file in: frontend/src/test/setup.ts
// Test setup configuration for Vitest

import '@testing-library/jest-dom';
import { vi, beforeAll, afterAll, afterEach } from 'vitest';

// Mock Next.js navigation
vi.mock('next/navigation', () => ({
	useRouter: () => ({
		push: vi.fn(),
		replace: vi.fn(),
		back: vi.fn(),
		forward: vi.fn(),
		refresh: vi.fn(),
		prefetch: vi.fn(),
	}),
	useSearchParams: () => ({
		get: vi.fn(),
		has: vi.fn(),
		toString: vi.fn(),
	}),
	usePathname: () => '/',
	notFound: vi.fn(),
}));

// Mock environment variables
Object.defineProperty(process.env, 'NEXT_PUBLIC_API_URL', {
	value: 'http://localhost:3000/api/v1',
	writable: true,
});

// Setup global test utilities
global.ResizeObserver = vi.fn().mockImplementation(() => ({
	observe: vi.fn(),
	unobserve: vi.fn(),
	disconnect: vi.fn(),
}));

// Mock fetch for API testing
global.fetch = vi.fn();

// Silence console.error during tests unless explicitly testing error states
const originalError = console.error;
beforeAll(() => {
	console.error = (...args: any[]) => {
		if (
			typeof args[0] === 'string' &&
			args[0].includes('Warning: ReactDOM.render is deprecated')
		) {
			return;
		}
		originalError.call(console, ...args);
	};
});

afterAll(() => {
	console.error = originalError;
});

// Clean up after each test
afterEach(() => {
	vi.clearAllMocks();
});
