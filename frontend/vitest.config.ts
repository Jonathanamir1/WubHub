/// <reference types="vitest" />
// Place this file in: frontend/vitest.config.ts

import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
	plugins: [react()],
	test: {
		// Test environment
		environment: 'jsdom',

		// Setup files to run before each test
		setupFiles: ['./src/test/setup.ts'],

		// Include test files
		include: [
			'src/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}',
			'__tests__/**/*.{js,mjs,cjs,ts,mts,cts,jsx,tsx}',
		],

		// Exclude files
		exclude: ['node_modules', '.next', 'dist', 'cypress', 'playwright'],

		// Global test configuration
		globals: true,

		// Coverage configuration
		coverage: {
			provider: 'v8',
			reporter: ['text', 'json', 'html'],
			include: ['src/**/*.{js,ts,jsx,tsx}'],
			exclude: [
				'src/test/**',
				'src/**/*.d.ts',
				'src/**/*.config.{js,ts}',
				'src/**/index.{js,ts}',
				'src/app/layout.tsx',
				'src/app/globals.css',
			],
			thresholds: {
				global: {
					branches: 80,
					functions: 80,
					lines: 80,
					statements: 80,
				},
			},
		},

		// Watch mode configuration
		watch: {
			include: ['src/**/*.{js,ts,jsx,tsx}'],
			exclude: ['node_modules', '.next'],
		},

		// Test timeout
		testTimeout: 10000,
		hookTimeout: 10000,
	},

	// Resolve aliases to match Next.js configuration
	resolve: {
		alias: {
			'@': resolve(__dirname, './src'),
			'@/components': resolve(__dirname, './src/components'),
			'@/lib': resolve(__dirname, './src/lib'),
			'@/hooks': resolve(__dirname, './src/hooks'),
			'@/types': resolve(__dirname, './src/types'),
			'@/utils': resolve(__dirname, './src/utils'),
		},
	},

	// Define global variables for testing
	define: {
		'process.env.NODE_ENV': '"test"',
	},
});
