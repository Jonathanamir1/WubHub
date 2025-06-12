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
				className={inter.className}
				style={{
					backgroundColor: '#1a1a1a',
					color: 'white',
					minHeight: '100vh',
				}}
			>
				{children}
			</body>
		</html>
	);
}
