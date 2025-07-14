// app/dashboard/page.tsx
'use client';

import { useAuth } from '../hooks/useAuth';
import { motion } from 'framer-motion';

export default function DashboardPage() {
	const { user, logout } = useAuth();

	return (
		<div className='min-h-screen bg-gray-900 p-8'>
			<motion.div
				className='max-w-6xl mx-auto'
				initial={{ opacity: 0, y: 20 }}
				animate={{ opacity: 1, y: 0 }}
				transition={{ duration: 0.5 }}
			>
				{/* Header */}
				<div className='flex justify-between items-center mb-8'>
					<div>
						<h1 className='text-3xl font-bold text-white'>
							Welcome back, {user?.name}!
						</h1>
						<p className='text-gray-400 mt-2'>
							Ready to organize your music projects?
						</p>
					</div>

					<motion.button
						onClick={logout}
						className='px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors'
						whileHover={{ scale: 1.05 }}
						whileTap={{ scale: 0.95 }}
					>
						Logout
					</motion.button>
				</div>

				{/* Dashboard Content */}
				<div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6'>
					<motion.div
						className='bg-gray-800 rounded-xl p-6 border border-gray-700'
						whileHover={{ scale: 1.02 }}
						transition={{ duration: 0.2 }}
					>
						<h3 className='text-xl font-semibold text-white mb-2'>
							Your Projects
						</h3>
						<p className='text-gray-400'>
							Manage your music projects and collaborations
						</p>
					</motion.div>

					<motion.div
						className='bg-gray-800 rounded-xl p-6 border border-gray-700'
						whileHover={{ scale: 1.02 }}
						transition={{ duration: 0.2 }}
					>
						<h3 className='text-xl font-semibold text-white mb-2'>
							Recent Activity
						</h3>
						<p className='text-gray-400'>
							Stay updated with your latest musical activities
						</p>
					</motion.div>

					<motion.div
						className='bg-gray-800 rounded-xl p-6 border border-gray-700'
						whileHover={{ scale: 1.02 }}
						transition={{ duration: 0.2 }}
					>
						<h3 className='text-xl font-semibold text-white mb-2'>Settings</h3>
						<p className='text-gray-400'>Customize your WubHub experience</p>
					</motion.div>
				</div>
			</motion.div>
		</div>
	);
}
