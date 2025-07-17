'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { useForm } from 'react-hook-form';
import { CreateWorkspaceRequest } from '../../lib/onboarding';

interface WorkspaceCreationFormProps {
	workspaceType: 'project_based' | 'client_based' | 'library';
	onSubmit: (data: CreateWorkspaceRequest) => Promise<void>;
	onBack: () => void;
	isProcessing: boolean;
}

interface FormData {
	name: string;
	description: string;
}

const workspaceTypeInfo = {
	project_based: {
		name: 'Project-Based Workspace',
		icon: '🎵',
		placeholder: 'My Music Studio',
		descriptionPlaceholder:
			'A space for all my music projects and creative work',
		examples: [
			'My Music Studio',
			'Creative Projects',
			'Personal Beats',
			'Song Development',
		],
	},
	client_based: {
		name: 'Client-Based Workspace',
		icon: '🏢',
		placeholder: 'Professional Studio',
		descriptionPlaceholder:
			'Managing client projects and professional collaborations',
		examples: [
			'Professional Studio',
			'Client Projects',
			'Freelance Work',
			'Studio Sessions',
		],
	},
	library: {
		name: 'Library Workspace',
		icon: '📚',
		placeholder: 'Sample Collection',
		descriptionPlaceholder: 'My collection of samples, loops, and references',
		examples: [
			'Sample Collection',
			'Sound Library',
			'Loop Bank',
			'Reference Archive',
		],
	},
};

export default function WorkspaceCreationForm({
	workspaceType,
	onSubmit,
	onBack,
	isProcessing,
}: WorkspaceCreationFormProps) {
	const [selectedExample, setSelectedExample] = useState<string | null>(null);
	const typeInfo = workspaceTypeInfo[workspaceType];

	const {
		register,
		handleSubmit,
		watch,
		setValue,
		formState: { errors, isValid },
	} = useForm<FormData>({
		mode: 'onChange',
		defaultValues: {
			name: '',
			description: '',
		},
	});

	const watchedName = watch('name');

	const handleFormSubmit = async (data: FormData) => {
		const workspaceData: CreateWorkspaceRequest = {
			name: data.name.trim(),
			description: data.description.trim() || undefined,
			workspace_type: workspaceType,
		};

		await onSubmit(workspaceData);
	};

	const handleExampleClick = (example: string) => {
		setSelectedExample(example);
		setValue('name', example);
	};

	const containerVariants = {
		hidden: { opacity: 0 },
		visible: {
			opacity: 1,
			transition: {
				staggerChildren: 0.1,
				delayChildren: 0.1,
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
				duration: 0.4,
				ease: [0.25, 0.46, 0.45, 0.94],
			},
		},
	};

	return (
		<motion.div
			key='workspace-creation-form'
			initial={{ opacity: 0, x: 20 }}
			animate={{ opacity: 1, x: 0 }}
			exit={{ opacity: 0, x: -20 }}
			transition={{ duration: 0.3 }}
		>
			<motion.div
				className='max-w-2xl mx-auto'
				variants={containerVariants}
				initial='hidden'
				animate='visible'
			>
				{/* Header */}
				<motion.div
					className='text-center mb-8'
					variants={itemVariants}
				>
					<div className='flex items-center justify-center gap-3 mb-4'>
						<span className='text-4xl'>{typeInfo.icon}</span>
						<h2 className='text-2xl font-semibold text-white'>
							Create Your {typeInfo.name}
						</h2>
					</div>
					<p className='text-gray-400'>
						Give your workspace a name and description to get started
					</p>
				</motion.div>

				{/* Form */}
				<form
					onSubmit={handleSubmit(handleFormSubmit)}
					className='space-y-6'
				>
					{/* Workspace Name */}
					<motion.div variants={itemVariants}>
						<label
							htmlFor='name'
							className='block text-sm font-medium text-gray-300 mb-2'
						>
							Workspace Name *
						</label>
						<input
							{...register('name', {
								required: 'Workspace name is required',
								minLength: {
									value: 2,
									message: 'Name must be at least 2 characters',
								},
								maxLength: {
									value: 50,
									message: 'Name must be less than 50 characters',
								},
							})}
							type='text'
							id='name'
							placeholder={typeInfo.placeholder}
							className='w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-colors'
						/>
						{errors.name && (
							<p className='mt-1 text-sm text-red-400'>{errors.name.message}</p>
						)}
					</motion.div>

					{/* Example Names */}
					<motion.div variants={itemVariants}>
						<p className='text-sm text-gray-400 mb-3'>
							Or choose from these examples:
						</p>
						<div className='grid grid-cols-2 gap-2'>
							{typeInfo.examples.map((example) => (
								<motion.button
									key={example}
									type='button'
									onClick={() => handleExampleClick(example)}
									className={`p-3 text-left rounded-lg border transition-all ${
										selectedExample === example || watchedName === example
											? 'border-blue-500 bg-blue-900/20 text-blue-300'
											: 'border-gray-700 bg-gray-800 text-gray-300 hover:border-gray-600'
									}`}
									whileHover={{ scale: 1.02 }}
									whileTap={{ scale: 0.98 }}
								>
									<span className='text-sm'>{example}</span>
								</motion.button>
							))}
						</div>
					</motion.div>

					{/* Description */}
					<motion.div variants={itemVariants}>
						<label
							htmlFor='description'
							className='block text-sm font-medium text-gray-300 mb-2'
						>
							Description (Optional)
						</label>
						<textarea
							{...register('description', {
								maxLength: {
									value: 500,
									message: 'Description must be less than 500 characters',
								},
							})}
							id='description'
							rows={3}
							placeholder={typeInfo.descriptionPlaceholder}
							className='w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-colors resize-none'
						/>
						{errors.description && (
							<p className='mt-1 text-sm text-red-400'>
								{errors.description.message}
							</p>
						)}
					</motion.div>

					{/* Preview */}
					{watchedName && (
						<motion.div
							variants={itemVariants}
							className='p-4 bg-gray-800 rounded-lg border border-gray-700'
						>
							<h3 className='text-sm font-medium text-gray-300 mb-2'>
								Preview:
							</h3>
							<div className='flex items-center gap-2 mb-1'>
								<span className='text-lg'>{typeInfo.icon}</span>
								<span className='text-white font-medium'>{watchedName}</span>
							</div>
							<p className='text-sm text-gray-400'>
								{workspaceType
									.replace('_', ' ')
									.replace(/\b\w/g, (l) => l.toUpperCase())}{' '}
								Workspace
							</p>
						</motion.div>
					)}

					{/* Navigation */}
					<motion.div
						variants={itemVariants}
						className='flex justify-between items-center pt-4'
					>
						<motion.button
							type='button'
							onClick={onBack}
							disabled={isProcessing}
							className='px-6 py-2 text-gray-400 hover:text-white disabled:text-gray-600 transition-colors'
							whileHover={{ scale: 1.05 }}
							whileTap={{ scale: 0.95 }}
						>
							← Back
						</motion.button>

						<motion.button
							type='submit'
							disabled={!isValid || isProcessing}
							className='px-8 py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-colors'
							whileHover={isValid && !isProcessing ? { scale: 1.05 } : {}}
							whileTap={isValid && !isProcessing ? { scale: 0.95 } : {}}
						>
							{isProcessing ? 'Creating Workspace...' : 'Create Workspace'}
						</motion.button>
					</motion.div>
				</form>
			</motion.div>
		</motion.div>
	);
}
