// src/app/layout.tsx
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
	title: 'WubHub - Music Collaboration Platform',
	description: 'Collaborate on music projects with real-time audio editing',
};

export default function RootLayout({
	children,
}: {
	children: React.ReactNode;
}) {
	return (
		<html
			lang='en'
			className='dark'
		>
			<body
				className={`${inter.className} bg-dark-800 text-white min-h-screen`}
			>
				{children}
			</body>
		</html>
	);
}
