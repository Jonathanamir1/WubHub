// app/auth/components/AuthLayout.tsx
'use client';

import { motion } from 'framer-motion';

interface AuthLayoutProps {
	children: React.ReactNode;
	title: string;
	subtitle?: string;
	footerText: string;
	footerLinkText: string;
	footerLinkHref: string;
}

export default function AuthLayout({
	children,
	title,
	subtitle,
	footerText,
	footerLinkText,
	footerLinkHref,
}: AuthLayoutProps) {
	const containerVariants = {
		hidden: { opacity: 0 },
		visible: {
			opacity: 1,
			transition: {
				staggerChildren: 0.2,
				delayChildren: 0.1,
			},
		},
	};

	const itemVariants = {
		hidden: {
			opacity: 0,
			y: 30,
			scale: 0.95,
		},
		visible: {
			opacity: 1,
			y: 0,
			scale: 1,
			transition: {
				duration: 0.6,
				ease: [0.25, 0.46, 0.45, 0.94], // Custom easing for smoothness
			},
		},
	};

	return (
		<div className='min-h-screen bg-gray-900 flex items-center justify-center p-4'>
			<motion.div
				className='w-full max-w-md'
				variants={containerVariants}
				initial='hidden'
				animate='visible'
			>
				{/* WubHub Logo/Brand */}
				<motion.div
					className='text-center mb-12'
					variants={itemVariants}
				>
					<motion.div
						className='flex items-center justify-center mb-6'
						variants={itemVariants}
					>
						<motion.div
							className='w-12 h-12 bg-gradient-to-br from-purple-500 to-blue-600 rounded-xl flex items-center justify-center'
							whileHover={{
								scale: 1.1,
								rotate: 5,
								transition: { duration: 0.2 },
							}}
						>
							<span className='text-white text-2xl font-bold'>W</span>
						</motion.div>
					</motion.div>
					<motion.h1
						className='text-3xl font-bold text-white mb-2'
						variants={itemVariants}
					>
						{title}
					</motion.h1>
					{subtitle && (
						<motion.p
							className='text-gray-400 text-base'
							variants={itemVariants}
						>
							{subtitle}
						</motion.p>
					)}
				</motion.div>

				{/* Auth Form Content */}
				<motion.div variants={itemVariants}>{children}</motion.div>

				{/* Footer Links */}
				<motion.div
					className='text-center mt-8 space-y-4'
					variants={itemVariants}
				>
					<motion.p
						className='text-gray-400 text-sm'
						variants={itemVariants}
					>
						{footerText}{' '}
						<motion.a
							href={footerLinkHref}
							className='text-blue-400 hover:text-blue-300 transition-colors'
							whileHover={{ scale: 1.05 }}
							whileTap={{ scale: 0.95 }}
						>
							{footerLinkText}
						</motion.a>
					</motion.p>

					<motion.p
						className='text-gray-500 text-xs leading-relaxed'
						variants={itemVariants}
					>
						By continuing, you agree to WubHub's{' '}
						<motion.a
							href='/terms'
							className='text-blue-400 hover:text-blue-300'
							whileHover={{ scale: 1.05 }}
							whileTap={{ scale: 0.95 }}
						>
							Terms of Use
						</motion.a>{' '}
						and{' '}
						<motion.a
							href='/privacy'
							className='text-blue-400 hover:text-blue-300'
							whileHover={{ scale: 1.05 }}
							whileTap={{ scale: 0.95 }}
						>
							Privacy Policy
						</motion.a>
						.
					</motion.p>
				</motion.div>
			</motion.div>
		</div>
	);
}
