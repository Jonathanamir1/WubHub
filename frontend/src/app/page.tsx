'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function Home() {
	const router = useRouter();

	useEffect(() => {
		// Check if user is already logged in
		const token = localStorage.getItem('wubhub_token');

		if (token) {
			// User is logged in, redirect to dashboard
			router.push('/dashboard');
		} else {
			// User is not logged in, redirect to login
			router.push('/login');
		}
	}, [router]);

	// Show loading while redirecting
	return (
		<div
			className='min-h-screen flex items-center justify-center'
			style={{ backgroundColor: '#1a1a1a' }}
		>
			<div className='text-white'>Loading...</div>
		</div>
	);
}
