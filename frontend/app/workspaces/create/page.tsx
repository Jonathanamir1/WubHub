// frontend/app/workspaces/create/page.tsx

'use client';

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle, Music, Users, Zap, Loader2 } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import {
	workspaceService,
	WORKSPACE_TYPES,
	WorkspaceType,
	CreateWorkspaceRequest,
} from '../../lib/workspace';

// Updated WORKSPACE_TYPES with Lucide icons
const WORKSPACE_TYPES_UI = {
	project_based: {
		id: 'project_based' as const,
		name: 'Project-Based',
		description:
			'Organize by individual music projects, albums, and creative work',
		icon: Music,
	},
	client_based: {
		id: 'client_based' as const,
		name: 'Client-Based',
		description: 'Manage projects and assets for specific clients or artists',
		icon: Users,
	},
	library: {
		id: 'library' as const,
		name: 'Library',
		description:
			'Curate and categorize your sound libraries, samples, and presets',
		icon: Zap,
	},
} as const;

export default function CreateWorkspacePage() {
	const { user } = useAuth();
	const router = useRouter();
	const searchParams = useSearchParams();

	const [selectedType, setSelectedType] = useState<WorkspaceType | null>(null);
	const [workspaceName, setWorkspaceName] = useState('');
	const [workspaceDescription, setWorkspaceDescription] = useState('');
	const [isCreating, setIsCreating] = useState(false);
	const [error, setError] = useState<string | null>(null);

	// Pre-select workspace type from URL parameter
	useEffect(() => {
		const typeParam = searchParams.get('type');
		if (typeParam && typeParam in WORKSPACE_TYPES_UI) {
			setSelectedType(typeParam as WorkspaceType);
		}
	}, [searchParams]);

	const handleTypeSelection = (type: WorkspaceType) => {
		setSelectedType(type);
		setError(null);
	};

	const handleCreateWorkspace = async () => {
		if (!selectedType || !workspaceName.trim()) {
			setError('Please select a workspace type and enter a name.');
			return;
		}

		setIsCreating(true);
		setError(null);

		try {
			const workspaceData: CreateWorkspaceRequest = {
				name: workspaceName.trim(),
				description: workspaceDescription.trim() || undefined,
				workspace_type: selectedType,
			};

			console.log('🚀 Creating workspace:', workspaceData);

			const createdWorkspace = await workspaceService.create(workspaceData);

			console.log('✅ Workspace created successfully:', createdWorkspace);

			// Redirect to the new workspace or dashboard
			router.push(`/workspaces/${createdWorkspace.id}`);
		} catch (error: any) {
			console.error('❌ Failed to create workspace:', error);
			setError(
				error.message || 'Failed to create workspace. Please try again.'
			);
		} finally {
			setIsCreating(false);
		}
	};

	const selectedTypeConfig = selectedType
		? WORKSPACE_TYPES_UI[selectedType]
		: null;

	return (
		<motion.div
			initial={{ opacity: 0, y: 20 }}
			animate={{ opacity: 1, y: 0 }}
			exit={{ opacity: 0, y: -20 }}
			transition={{ duration: 0.3 }}
			className='min-h-screen bg-gray-900'
		>
			<div className='max-w-7xl mx-auto p-6'>
				{/* Main content - Side by side like step 7, centered */}
				<div className='grid lg:grid-cols-2 gap-8 mb-8 max-w-6xl mx-auto'>
					{/* Left Panel - Workspace Type Selection */}
					<div className='bg-gray-800 rounded-2xl shadow-xl p-8 min-h-[600px] border border-gray-700'>
						<div className='h-full'>
							<div className='space-y-6'>
								<h3 className='text-xl font-bold mb-6 text-white'>
									Choose Your Organization Type
								</h3>
								<div className='space-y-4'>
									{Object.entries(WORKSPACE_TYPES_UI).map(
										([key, typeConfig]) => {
											const IconComponent = typeConfig.icon;
											const isSelected = selectedType === key;
											return (
												<div
													key={key}
													onClick={() =>
														handleTypeSelection(key as WorkspaceType)
													}
													className={`cursor-pointer transition-all hover:shadow-lg rounded-xl border p-4 ${
														isSelected
															? 'ring-2 ring-blue-500 bg-blue-900/20 border-blue-500'
															: 'bg-gray-700 border-gray-600 hover:border-gray-500'
													}`}
												>
													<div className='flex items-center gap-3 mb-3'>
														<div
															className={`w-10 h-10 rounded-lg flex items-center justify-center ${
																isSelected ? 'bg-blue-500' : 'bg-blue-600'
															}`}
														>
															<IconComponent className='w-5 h-5 text-white' />
														</div>
														<div className='flex-1'>
															<h3 className='text-base font-semibold text-white'>
																{typeConfig.name}
															</h3>
															<p className='text-sm text-gray-400'>
																{typeConfig.description}
															</p>
														</div>
														{isSelected && (
															<CheckCircle className='w-5 h-5 text-blue-400' />
														)}
													</div>
												</div>
											);
										}
									)}
								</div>
							</div>
						</div>
					</div>

					{/* Right Panel - Form */}
					<div className='bg-gray-800 rounded-2xl shadow-xl p-8 flex flex-col justify-center min-h-[600px] border border-gray-700'>
						<div className='space-y-6'>
							<div className='w-16 h-16 bg-gradient-to-br from-green-500 to-blue-600 rounded-2xl flex items-center justify-center'>
								{selectedTypeConfig ? (
									<selectedTypeConfig.icon className='w-8 h-8 text-white' />
								) : (
									<Music className='w-8 h-8 text-white' />
								)}
							</div>
							<div>
								<h1 className='text-4xl font-bold mb-4 text-white'>
									Create Your Workspace
								</h1>
								<p className='text-xl text-gray-300 leading-relaxed'>
									{selectedTypeConfig
										? `Setting up your ${selectedTypeConfig.name} workspace`
										: 'Choose your workspace type and get started'}
								</p>
							</div>

							{/* Error Message */}
							<AnimatePresence>
								{error && (
									<motion.div
										initial={{ opacity: 0, y: -10 }}
										animate={{ opacity: 1, y: 0 }}
										exit={{ opacity: 0, y: -10 }}
										className='p-4 bg-red-900/20 border border-red-700 rounded-lg'
									>
										<p className='text-red-300 text-sm'>{error}</p>
									</motion.div>
								)}
							</AnimatePresence>

							{/* Form Fields */}
							<div className='space-y-4'>
								{/* Workspace Name */}
								<div>
									<label className='block text-sm font-medium text-gray-300 mb-2'>
										Workspace Name*
									</label>
									<input
										type='text'
										value={workspaceName}
										onChange={(e) => setWorkspaceName(e.target.value)}
										placeholder='Enter workspace name'
										className='w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500'
									/>
								</div>

								{/* Workspace Description */}
								<div>
									<label className='block text-sm font-medium text-gray-300 mb-2'>
										Description (Optional)
									</label>
									<textarea
										value={workspaceDescription}
										onChange={(e) => setWorkspaceDescription(e.target.value)}
										placeholder='Describe your workspace...'
										rows={3}
										className='w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 resize-none'
									/>
								</div>
							</div>

							{/* Selected Type Display */}
							{selectedTypeConfig && (
								<div className='space-y-3'>
									<div className='flex items-center gap-3 text-sm'>
										<CheckCircle className='w-5 h-5 text-green-400' />
										<span className='text-gray-300'>
											{selectedTypeConfig.name} organization selected
										</span>
									</div>
									<div className='flex items-center gap-3 text-sm'>
										<CheckCircle className='w-5 h-5 text-green-400' />
										<span className='text-gray-300'>
											Smart structure enabled
										</span>
									</div>
									<div className='flex items-center gap-3 text-sm'>
										<CheckCircle className='w-5 h-5 text-green-400' />
										<span className='text-gray-300'>
											Ready for file uploads
										</span>
									</div>
								</div>
							)}
						</div>
					</div>
				</div>

				{/* Navigation - Bottom of page like other pages */}
				<div className='flex justify-between max-w-6xl mx-auto'>
					<button
						onClick={() => router.push('/')}
						className='flex items-center gap-2 bg-gray-700 border border-gray-600 hover:border-gray-500 hover:bg-gray-600 px-6 py-3 rounded-lg transition-colors text-gray-300'
					>
						Cancel
					</button>

					<button
						onClick={handleCreateWorkspace}
						disabled={isCreating || !selectedType || !workspaceName.trim()}
						className='flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed'
					>
						{isCreating ? (
							<>
								<Loader2 className='w-4 h-4 animate-spin' />
								Creating Workspace...
							</>
						) : (
							'Create Workspace'
						)}
					</button>
				</div>
			</div>
		</motion.div>
	);
}
