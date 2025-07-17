'use client';

import { motion } from 'framer-motion';
import { WorkspaceResponse } from '../../lib/onboarding';

interface OnboardingCompleteProps {
	workspace: WorkspaceResponse;
	onComplete: () => void;
}

const workspaceTypeInfo = {
	project_based: {
		icon: '🎵',
		nextSteps: [
			'Create your first music project',
			'Upload your tracks and samples',
			'Organize your creative workflow',
		],
		tips: [
			'Use projects to separate different albums or singles',
			'Keep track of your creative process',
			'Collaborate with other artists',
		],
	},
	client_based: {
		icon: '🏢',
		nextSteps: [
			'Add your first client',
			'Create client projects',
			'Manage professional workflows',
		],
		tips: [
			'Organize work by client for better project management',
			'Keep client files separate and secure',
			'Track project progress and deadlines',
		],
	},
	library: {
		icon: '📚',
		nextSteps: [
			'Upload your sample collections',
			'Organize your sound library',
			'Create reference collections',
		],
		tips: [
			'Tag samples for easy searching',
			'Create categories that make sense to you',
			'Build a comprehensive reference library',
		],
	},
};

export default function OnboardingComplete({
	workspace,
	onComplete,
}: OnboardingCompleteProps) {
	const workspaceTypeKey =
		workspace.workspace_type as keyof typeof workspaceTypeInfo;
	const typeInfo =
		workspaceTypeInfo[workspaceTypeKey] || workspaceTypeInfo.project_based;

	const containerVariants = {
		hidden: { opacity: 0 },
		visible: {
			opacity: 1,
			transition: {
				staggerChildren: 0.1,
				delayChildren: 0.2,
			},
		},
	};

	const itemVariants = {
		hidden: {
			opacity: 0,
			y: 20,
		},
		visible: {
			opacity: 1,
			y: 0,
			transition: {
				duration: 0.5,
				ease: [0.25, 0.46, 0.45, 0.94],
			},
		},
	};

	const successVariants = {
		hidden: { scale: 0, opacity: 0 },
		visible: {
			scale: 1,
			opacity: 1,
			transition: {
				type: 'spring',
				stiffness: 200,
				damping: 15,
				delay: 0.1,
			},
		},
	};

	return (
		<motion.div
			key='onboarding-complete'
			initial={{ opacity: 0, x: 20 }}
			animate={{ opacity: 1, x: 0 }}
			exit={{ opacity: 0, x: -20 }}
			transition={{ duration: 0.3 }}
		>
			<motion.div
				className='max-w-3xl mx-auto text-center'
				variants={containerVariants}
				initial='hidden'
				animate='visible'
			>
				{/* Success Icon */}
				<motion.div
					className='mb-8'
					variants={successVariants}
				>
					<div className='relative inline-block'>
						<motion.div
							className='w-24 h-24 bg-gradient-to-br from-green-500 to-blue-600 rounded-full flex items-center justify-center mx-auto mb-4'
							animate={{
								scale: [1, 1.05, 1],
							}}
							transition={{
								duration: 2,
								repeat: Infinity,
								ease: 'easeInOut',
							}}
						>
							<span className='text-white text-4xl'>✓</span>
						</motion.div>
						<motion.div
							className='absolute inset-0 bg-gradient-to-br from-green-500 to-blue-600 rounded-full opacity-30'
							animate={{
								scale: [1, 1.2, 1],
								opacity: [0.3, 0.1, 0.3],
							}}
							transition={{
								duration: 2,
								repeat: Infinity,
								ease: 'easeInOut',
							}}
						/>
					</div>
				</motion.div>

				{/* Success Message */}
				<motion.div
					variants={itemVariants}
					className='mb-8'
				>
					<h2 className='text-3xl font-bold text-white mb-4'>
						🎉 Welcome to WubHub!
					</h2>
					<p className='text-xl text-gray-300 mb-2'>
						Your workspace is ready to rock
					</p>
					<p className='text-gray-400'>
						You've successfully created your first workspace and you're all set
						to start organizing your music.
					</p>
				</motion.div>

				{/* Workspace Summary */}
				<motion.div
					variants={itemVariants}
					className='bg-gray-800 rounded-xl p-6 border border-gray-700 mb-8'
				>
					<div className='flex items-center justify-center gap-3 mb-4'>
						<span className='text-3xl'>{typeInfo.icon}</span>
						<div className='text-left'>
							<h3 className='text-xl font-semibold text-white'>
								{workspace.name}
							</h3>
							<p className='text-sm text-gray-400'>
								{workspace.workspace_type_display}
							</p>
						</div>
					</div>
					{workspace.description && (
						<p className='text-gray-300 text-sm'>{workspace.description}</p>
					)}
				</motion.div>

				{/* Next Steps */}
				<div className='grid grid-cols-1 md:grid-cols-2 gap-6 mb-8'>
					{/* What's Next */}
					<motion.div
						variants={itemVariants}
						className='bg-gray-800 rounded-xl p-6 border border-gray-700'
					>
						<h4 className='text-lg font-semibold text-white mb-4'>
							🚀 What's Next
						</h4>
						<ul className='space-y-2 text-left'>
							{typeInfo.nextSteps.map((step, index) => (
								<li
									key={index}
									className='flex items-start gap-2'
								>
									<span className='text-blue-500 mt-1 text-sm'>•</span>
									<span className='text-gray-300 text-sm'>{step}</span>
								</li>
							))}
						</ul>
					</motion.div>

					{/* Pro Tips */}
					<motion.div
						variants={itemVariants}
						className='bg-gray-800 rounded-xl p-6 border border-gray-700'
					>
						<h4 className='text-lg font-semibold text-white mb-4'>
							💡 Pro Tips
						</h4>
						<ul className='space-y-2 text-left'>
							{typeInfo.tips.map((tip, index) => (
								<li
									key={index}
									className='flex items-start gap-2'
								>
									<span className='text-yellow-500 mt-1 text-sm'>•</span>
									<span className='text-gray-300 text-sm'>{tip}</span>
								</li>
							))}
						</ul>
					</motion.div>
				</div>

				{/* Call to Action */}
				<motion.div variants={itemVariants}>
					<p className='text-gray-400 mb-6'>
						Ready to start organizing your music? Let's dive into your new
						workspace!
					</p>
					<motion.button
						onClick={onComplete}
						className='px-8 py-4 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white rounded-lg font-medium text-lg transition-all duration-200'
						whileHover={{ scale: 1.05 }}
						whileTap={{ scale: 0.95 }}
					>
						Enter Your Workspace
					</motion.button>
				</motion.div>

				{/* Footer */}
				<motion.div
					variants={itemVariants}
					className='mt-8 pt-6 border-t border-gray-700'
				>
					<p className='text-sm text-gray-500'>
						Need help getting started? Check out our{' '}
						<a
							href='#'
							className='text-blue-400 hover:text-blue-300 transition-colors'
						>
							documentation
						</a>{' '}
						or{' '}
						<a
							href='#'
							className='text-blue-400 hover:text-blue-300 transition-colors'
						>
							contact support
						</a>
					</p>
				</motion.div>
			</motion.div>
		</motion.div>
	);
}
