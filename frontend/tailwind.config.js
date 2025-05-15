// tailwind.config.js
/** @type {import('tailwindcss').Config} */
export default {
	content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
	theme: {
		extend: {
			colors: {
				// Ableton-inspired dark mode colors
				'ableton-dark': {
					50: '#2C2C2C',
					100: '#252525',
					200: '#202020',
					300: '#1A1A1A',
					400: '#161616',
					500: '#121212',
					600: '#0E0E0E',
					700: '#0A0A0A',
					800: '#080808',
					900: '#050505',
				},
				'ableton-accent': {
					50: '#F8FAFC',
					100: '#F1F5F9',
					200: '#E2E8F0',
					300: '#CBD5E1',
					400: '#94A3B8',
					500: '#64748B',
					600: '#475569',
					700: '#334155',
					800: '#1E293B',
					900: '#0F172A',
					950: '#020617',
				},
				'ableton-blue': {
					DEFAULT: '#0000FF',
					50: '#E5E5FF',
					100: '#CCCCFF',
					200: '#9999FF',
					300: '#6666FF',
					400: '#3333FF',
					500: '#0000FF',
					600: '#0000CC',
					700: '#000099',
					800: '#000066',
					900: '#000033',
				},
				'ableton-purple': {
					DEFAULT: '#AF00FF',
					50: '#F5E5FF',
					100: '#EBCCFF',
					200: '#D699FF',
					300: '#C266FF',
					400: '#AD33FF',
					500: '#AF00FF',
					600: '#8B00CC',
					700: '#680099',
					800: '#440066',
					900: '#220033',
				},
			},
		},
	},
	plugins: [],
};
