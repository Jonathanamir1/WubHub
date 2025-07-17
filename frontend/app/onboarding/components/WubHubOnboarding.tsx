// frontend/app/onboarding/components/WubHubOnboarding.tsx

'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
	ChevronRight,
	ChevronLeft,
	Folder,
	Music,
	Users,
	FileAudio,
	Zap,
	Upload,
	CheckCircle,
	ArrowRight,
} from 'lucide-react';

interface WubHubOnboardingProps {
	onSelect: (
		type: 'project_based' | 'client_based' | 'library'
	) => Promise<void>;
	onBack: () => void;
	isProcessing: boolean;
}

const organizationMethods = [
	{
		id: 'client_based',
		title: 'Client-Based Organization',
		description:
			'Perfect for producers working with multiple clients and labels',
		icon: Users,
		color: 'bg-green-500',
		levels: [
			{ level: 0, name: 'Workspace', example: 'Pro Studio', icon: Folder },
			{
				level: 1,
				name: 'Clients',
				example: 'Sony Music, Local Studio, Artist Name',
				icon: Users,
			},
			{
				level: 2,
				name: 'Client Projects',
				example: 'Album 2024, Single Release',
				icon: Music,
			},
			{
				level: 3,
				name: 'Project Files',
				example: '.als, .wav, .mp3 files',
				icon: FileAudio,
			},
		],
		useCase:
			'When you work with record labels, multiple artists, or need to separate client work clearly',
		example: 'Pro Studio → Sony Music → Album 2024 → track.als',
		detailedBenefits: [
			'Keep client work completely separate',
			'Easy billing and project tracking',
			'Professional organization for labels',
			'Scale with multiple clients',
		],
	},
	{
		id: 'project_based',
		title: 'Project-Based Organization',
		description: 'Ideal for independent artists and personal projects',
		icon: Music,
		color: 'bg-blue-500',
		levels: [
			{ level: 0, name: 'Workspace', example: 'My Music', icon: Folder },
			{
				level: 1,
				name: 'Projects',
				example: 'My Album, Beat Pack, Remix Collection',
				icon: Music,
			},
			{
				level: 2,
				name: 'Project Files',
				example: '.als, .wav, .mp3 files',
				icon: FileAudio,
			},
		],
		useCase:
			"When you're working on your own music or don't need client separation",
		example: 'My Music → My Album → track.als',
		detailedBenefits: [
			'Simple and straightforward',
			'Perfect for solo artists',
			'Quick access to all projects',
			'Less folder complexity',
		],
	},
	{
		id: 'library',
		title: 'Library Organization',
		description: 'Complete freedom for experimental and flexible workflows',
		icon: Zap,
		color: 'bg-orange-500',
		levels: [
			{ level: 0, name: 'Workspace', example: 'Creative Vault', icon: Folder },
			{
				level: 1,
				name: 'Collections',
				example: 'Hip-Hop Drums, Ambient Textures',
				icon: Upload,
			},
			{
				level: 2,
				name: 'Files',
				example: '.wav, .mp3, samples',
				icon: FileAudio,
			},
		],
		useCase:
			'When you prefer flexible organization and want to collect samples and references',
		example: 'Creative Vault → Hip-Hop Drums → kick.wav',
		detailedBenefits: [
			'Total creative freedom',
			'Perfect for sample collections',
			'Organize as you go',
			'Great for experimentation',
		],
	},
];

export default function WubHubOnboarding({
	onSelect,
	onBack,
	isProcessing,
}: WubHubOnboardingProps) {
	const [currentStep, setCurrentStep] = useState(0);
	const [selectedMethod, setSelectedMethod] = useState<
		'project_based' | 'client_based' | 'library' | null
	>(null);
	const router = useRouter();

	const steps = [
		'welcome',
		'explanation',
		'client_based',
		'project_based',
		'library',
		'selection',
		'confirmation',
	];

	const nextStep = () => {
		if (currentStep < steps.length - 1) {
			setCurrentStep(currentStep + 1);
		}
	};

	const prevStep = () => {
		if (currentStep > 0) {
			setCurrentStep(currentStep - 1);
		}
	};

	const selectMethod = (methodId: string) => {
		setSelectedMethod(methodId as 'project_based' | 'client_based' | 'library');
		// Skip to selection step
		setCurrentStep(5);
	};

	const handleCreateWorkspace = (workspaceType: string) => {
		// Redirect to workspace creation page with pre-selected type
		router.push(`/workspaces/create?type=${workspaceType}`);
	};

	const handleFinalSelection = async () => {
		if (selectedMethod) {
			await onSelect(selectedMethod);
		}
	};

	const renderLeftPanel = () => {
		switch (steps[currentStep]) {
			case 'welcome':
				return (
					<div className='space-y-10 text-center justify-center items-center'>
						<div className='w-16 h-16 bg-gradient-to-br from-blue-500 to-purple-600 rounded-2xl flex items-center justify-center mx-auto'>
							<Music className='w-8 h-8 text-white' />
						</div>
						<div>
							<h1 className='text-4xl font-bold mb-4 text-white'>
								Welcome to WubHub
							</h1>
						</div>
						<div className=' rounded-lg p-6 border border-gray-600'>
							<p className='text-l text-gray-400'>
								A music collaboration platform that transforms chaotic project
								folders into organized workspaces with powerful collaboration
								tools - version comparisons, grouped downloads, and intelligent
								file organization.
							</p>
						</div>
					</div>
				);

			case 'explanation':
				return (
					<div className='space-y-6'>
						<div>
							<h2 className='text-3xl font-bold mb-4 text-white'>
								How WubHub Works
							</h2>
							<p className='text-lg text-gray-300 leading-relaxed'>
								WubHub creates intelligent views of your files based on your
								workflow
							</p>
						</div>
						<div className='space-y-4'>
							<div className='flex items-start gap-4'>
								<div className='w-8 h-8 bg-blue-500/20 rounded-lg flex items-center justify-center flex-shrink-0 mt-1 border border-blue-500/30'>
									<span className='text-blue-400 font-bold text-sm'>1</span>
								</div>
								<div>
									<h3 className='font-semibold mb-1 text-white'>
										Drop Your Files
									</h3>
									<p className='text-sm text-gray-400'>
										Drag your files and folders directly into your desired
										workspace
									</p>
								</div>
							</div>
							<div className='flex items-start gap-4'>
								<div className='w-8 h-8 bg-green-500/20 rounded-lg flex items-center justify-center flex-shrink-0 mt-1 border border-green-500/30'>
									<span className='text-green-400 font-bold text-sm'>2</span>
								</div>
								<div>
									<h3 className='font-semibold mb-1 text-white'>Smart Views</h3>
									<p className='text-sm text-gray-400'>
										WubHub automatically creates the right view for your
										workflow
									</p>
								</div>
							</div>
							<div className='flex items-start gap-4'>
								<div className='w-8 h-8 bg-purple-500/20 rounded-lg flex items-center justify-center flex-shrink-0 mt-1 border border-purple-500/30'>
									<span className='text-purple-400 font-bold text-sm'>3</span>
								</div>
								<div>
									<h3 className='font-semibold mb-1 text-white'>
										Creative Focus
									</h3>
									<p className='text-sm text-gray-400'>
										Navigate the app through magic mode, or switch to browse,
										share, and edit your files normally.
									</p>
								</div>
							</div>
						</div>
					</div>
				);

			case 'client_based':
			case 'project_based':
			case 'library':
				const method = organizationMethods.find(
					(m) => m.id === steps[currentStep]
				);
				if (!method) return null;
				const IconComponent = method.icon;

				return (
					<div className='space-y-6'>
						<div className='flex items-center gap-4'>
							<div
								className={`w-16 h-16 ${method.color} rounded-2xl flex items-center justify-center`}
							>
								<IconComponent className='w-8 h-8 text-white' />
							</div>
							<div>
								<h2 className='text-3xl font-bold mb-2 text-white'>
									{method.title}
								</h2>
								<p className='text-lg text-gray-300'>{method.description}</p>
							</div>
						</div>

						<div className='space-y-4'>
							<div>
								<h3 className='font-semibold mb-3 text-white'>Perfect for:</h3>
								<p className='text-gray-400'>{method.useCase}</p>
							</div>

							<div>
								<h3 className='font-semibold mb-3 text-white'>Key Benefits:</h3>
								<div className='space-y-2'>
									{method.detailedBenefits.map((benefit, index) => (
										<div
											key={index}
											className='flex items-center gap-3'
										>
											<CheckCircle className='w-4 h-4 text-green-400 flex-shrink-0' />
											<span className='text-sm text-gray-300'>{benefit}</span>
										</div>
									))}
								</div>
							</div>

							<div className='p-4 bg-gray-700/50 rounded-lg border border-gray-600'>
								<h4 className='font-semibold mb-2 text-white'>
									Example Structure:
								</h4>
								<div className='font-mono text-sm bg-gray-900 rounded p-2 border border-gray-600 text-gray-300'>
									{method.example}
								</div>
							</div>
						</div>
					</div>
				);

			case 'selection':
				return (
					<div className='space-y-6'>
						<div>
							<h2 className='text-3xl font-bold mb-4 text-white'>
								Choose Your Organization Style
							</h2>
							<p className='text-lg text-gray-300 leading-relaxed'>
								Pick the method that matches how you work with music
							</p>
						</div>
						<div className='p-4 bg-amber-900/20 rounded-lg border-l-4 border-amber-500'>
							<h4 className='font-semibold text-amber-400 mb-1'>💡 Remember</h4>
							<p className='text-sm text-amber-300'>
								You can always change your organization method later in
								workspace settings.
							</p>
						</div>
					</div>
				);

			case 'confirmation':
				return (
					<div className='space-y-6'>
						<div className='w-16 h-16 bg-gradient-to-br from-green-500 to-blue-600 rounded-2xl flex items-center justify-center'>
							<CheckCircle className='w-8 h-8 text-white' />
						</div>
						<div>
							<h1 className='text-4xl font-bold mb-4 text-white'>
								You're All Set! 🎉
							</h1>
							<p className='text-xl text-gray-300 leading-relaxed'>
								Your workspace is ready for music creation
							</p>
						</div>
						<div className='space-y-3'>
							<div className='flex items-center gap-3 text-sm'>
								<CheckCircle className='w-5 h-5 text-green-400' />
								<span className='text-gray-300'>
									Organization method configured
								</span>
							</div>
							<div className='flex items-center gap-3 text-sm'>
								<CheckCircle className='w-5 h-5 text-green-400' />
								<span className='text-gray-300'>Workspace ready for files</span>
							</div>
							<div className='flex items-center gap-3 text-sm'>
								<CheckCircle className='w-5 h-5 text-green-400' />
								<span className='text-gray-300'>Smart structure enabled</span>
							</div>
						</div>
					</div>
				);

			default:
				return null;
		}
	};

	const renderRightPanel = () => {
		switch (steps[currentStep]) {
			case 'welcome':
				return (
					<div className='bg-gradient-to-br from-blue-900/30 to-purple-900/30 rounded-2xl p-8 h-full flex flex-col justify-center border border-gray-600'>
						<div className='text-center space-y-6'>
							<div className='relative'>
								<div className='w-32 h-32 bg-gray-800 rounded-3xl shadow-lg mx-auto flex items-center justify-center border border-gray-600'>
									<div className='w-20 h-20 bg-gradient-to-br from-blue-500 to-purple-600 rounded-2xl flex items-center justify-center'>
										<Folder className='w-10 h-10 text-white' />
									</div>
								</div>
								<div className='absolute -top-2 -right-2 w-8 h-8 bg-green-500 rounded-full flex items-center justify-center'>
									<Zap className='w-4 h-4 text-white' />
								</div>
							</div>
							<div>
								<h3 className='text-2xl font-bold mb-2 text-white'>
									Smart File Organization
								</h3>
								<p className='text-gray-300'>
									Files organize automatically into the perfect structure for
									your workflow
								</p>
							</div>
						</div>
					</div>
				);

			case 'explanation':
				return (
					<div className='space-y-6'>
						<div className='border-2 border-dashed border-blue-500/30 bg-blue-500/10 rounded-xl p-6'>
							<div className='flex items-center gap-3 mb-4'>
								<Upload className='w-6 h-6 text-blue-400' />
								<span className='font-semibold text-lg text-white'>
									Drop Your Files
								</span>
							</div>
							<p className='text-sm text-gray-400 mb-4'>
								Drag your files and folders directly into your desired workspace
							</p>
							<div className='grid grid-cols-3 gap-3'>
								<div className='bg-gray-700 rounded-lg p-3 text-center shadow-sm border border-gray-600'>
									<FileAudio className='w-6 h-6 mx-auto mb-1 text-blue-400' />
									<span className='text-xs text-gray-300'>.als</span>
								</div>
								<div className='bg-gray-700 rounded-lg p-3 text-center shadow-sm border border-gray-600'>
									<FileAudio className='w-6 h-6 mx-auto mb-1 text-green-400' />
									<span className='text-xs text-gray-300'>.wav</span>
								</div>
								<div className='bg-gray-700 rounded-lg p-3 text-center shadow-sm border border-gray-600'>
									<FileAudio className='w-6 h-6 mx-auto mb-1 text-purple-400' />
									<span className='text-xs text-gray-300'>.mp3</span>
								</div>
							</div>
						</div>

						<div className='flex justify-center'>
							<ArrowRight className='w-8 h-8 text-gray-500 animate-pulse' />
						</div>

						<div className='bg-gradient-to-r from-green-500/10 to-blue-500/10 rounded-xl p-6 border border-gray-600'>
							<div className='flex items-center gap-3 mb-4'>
								<Zap className='w-6 h-6 text-green-400' />
								<span className='font-semibold text-lg text-white'>
									Smart Views
								</span>
							</div>
							<p className='text-sm text-gray-400 mb-4'>
								WubHub automatically creates the right view for your workflow
							</p>
							<div className='space-y-2'>
								<div className='flex items-center gap-2 text-sm'>
									<Folder className='w-4 h-4 text-gray-400' />
									<span className='text-gray-300'>Workspace</span>
								</div>
								<div className='flex items-center gap-2 text-sm pl-4'>
									<Users className='w-4 h-4 text-blue-400' />
									<span className='text-gray-300'>Client / Project</span>
								</div>
								<div className='flex items-center gap-2 text-sm pl-8'>
									<FileAudio className='w-4 h-4 text-green-400' />
									<span className='text-gray-300'>Your Files</span>
								</div>
							</div>
						</div>
					</div>
				);

			case 'client_based':
			case 'project_based':
			case 'library':
				const method = organizationMethods.find(
					(m) => m.id === steps[currentStep]
				);
				if (!method) return null;

				// Define the gradient classes based on method color
				let gradientClass =
					'bg-gradient-to-br from-blue-900/20 to-purple-900/20';
				if (method.color === 'bg-green-500') {
					gradientClass = 'bg-gradient-to-br from-green-900/20 to-blue-900/20';
				} else if (method.color === 'bg-blue-500') {
					gradientClass = 'bg-gradient-to-br from-blue-900/20 to-purple-900/20';
				} else if (method.color === 'bg-orange-500') {
					gradientClass =
						'bg-gradient-to-br from-orange-900/20 to-purple-900/20';
				}

				return (
					<div className='space-y-6'>
						<div
							className={`${gradientClass} border-2 border-gray-600 rounded-xl p-8`}
						>
							<div className='space-y-6'>
								<div>
									<h3 className='text-xl font-bold mb-4 text-white'>
										File Structure Preview
									</h3>
									<div className='space-y-3'>
										{method.levels.map((level, index) => {
											const LevelIcon = level.icon;
											return (
												<div
													key={index}
													className='flex items-center gap-3'
													style={{ marginLeft: `${index * 16}px` }}
												>
													<div className='w-10 h-10 bg-gray-700 rounded-lg flex items-center justify-center shadow-sm border border-gray-600'>
														<LevelIcon className='w-5 h-5 text-gray-300' />
													</div>
													<div>
														<div className='font-medium text-sm text-white'>
															Level {level.level}: {level.name}
														</div>
														<div className='text-xs text-gray-400'>
															{level.example}
														</div>
													</div>
												</div>
											);
										})}
									</div>
								</div>

								<div className='p-4 bg-gray-800/80 rounded-lg border border-gray-600'>
									<div className='text-sm font-semibold mb-2 text-white'>
										📁 Example Path:
									</div>
									<div className='text-sm font-mono bg-gray-900 rounded p-2 border border-gray-700 text-gray-300'>
										{method.example}
									</div>
								</div>
							</div>
						</div>

						<div className='text-center'>
							<button
								onClick={() => handleCreateWorkspace(method.id)}
								className={`${method.color} hover:opacity-90 text-white px-8 py-3 rounded-lg font-semibold transition-opacity`}
							>
								Create Workspace
							</button>
						</div>
					</div>
				);

			case 'selection':
				return (
					<div className='h-full flex flex-col'>
						<div className='flex-1 overflow-y-auto'>
							<div className='grid gap-3'>
								{organizationMethods.map((method) => {
									const IconComponent = method.icon;
									return (
										<div
											key={method.id}
											className={`cursor-pointer transition-all hover:shadow-lg rounded-xl border p-4 ${
												selectedMethod === method.id
													? 'ring-2 ring-blue-500 bg-blue-900/20 border-blue-500'
													: 'bg-gray-700 border-gray-600'
											}`}
											onClick={() =>
												setSelectedMethod(
													method.id as
														| 'project_based'
														| 'client_based'
														| 'library'
												)
											}
										>
											<div className='flex items-center gap-3 mb-3'>
												<div
													className={`w-10 h-10 ${method.color} rounded-lg flex items-center justify-center`}
												>
													<IconComponent className='w-5 h-5 text-white' />
												</div>
												<div className='flex-1'>
													<h3 className='text-base font-semibold text-white'>
														{method.title}
													</h3>
													<p className='text-sm text-gray-400'>
														{method.description}
													</p>
												</div>
												{selectedMethod === method.id && (
													<CheckCircle className='w-5 h-5 text-blue-400' />
												)}
											</div>
											<div className='space-y-2'>
												<div className='text-xs font-medium text-gray-400'>
													File Structure:
												</div>
												<div className='flex flex-wrap gap-1'>
													{method.levels.map((level, index) => (
														<div
															key={index}
															className='flex items-center gap-1'
														>
															<span className='px-1.5 py-0.5 bg-gray-600 text-gray-300 rounded text-xs border border-gray-500'>
																{level.name}
															</span>
															{index < method.levels.length - 1 && (
																<ChevronRight className='w-2 h-2 text-gray-500' />
															)}
														</div>
													))}
												</div>
												<div className='text-xs text-gray-400 bg-gray-800/50 rounded p-2 border border-gray-600'>
													<strong className='text-gray-300'>Best for:</strong>{' '}
													{method.useCase}
												</div>
											</div>
										</div>
									);
								})}
							</div>
						</div>
					</div>
				);

			case 'confirmation':
				const confirmedMethod = organizationMethods.find(
					(m) => m.id === selectedMethod
				);
				if (!confirmedMethod) return null;

				return (
					<div className='bg-gradient-to-br from-green-900/20 to-blue-900/20 rounded-2xl p-8 h-full flex flex-col justify-center border border-gray-600'>
						<div className='text-center space-y-6'>
							<div className='w-32 h-32 bg-gray-800 rounded-3xl shadow-lg mx-auto flex items-center justify-center border border-gray-600'>
								<div className='w-20 h-20 bg-gradient-to-br from-green-500 to-blue-600 rounded-2xl flex items-center justify-center'>
									<Music className='w-10 h-10 text-white' />
								</div>
							</div>
							<div>
								<h3 className='text-2xl font-bold mb-2 text-white'>
									Ready to start creating?
								</h3>
								<p className='text-gray-300 mb-4'>
									Your workspace is configured with {confirmedMethod.title}
								</p>
								<div className='text-sm bg-gray-800/80 rounded-lg p-4 border border-gray-600'>
									<div className='space-y-1 text-left'>
										<p className='text-gray-300'>
											✨ Drop your first audio files to see the magic happen
										</p>
										<p className='text-gray-300'>
											🎵 Your files will automatically organize into the perfect
											structure
										</p>
										<p className='text-gray-300'>
											⚙️ You can always change your organization method in
											settings
										</p>
									</div>
								</div>
							</div>
						</div>
					</div>
				);

			default:
				return null;
		}
	};

	return (
		<motion.div
			initial={{ opacity: 0, y: 20 }}
			animate={{ opacity: 1, y: 0 }}
			exit={{ opacity: 0, y: -20 }}
			transition={{ duration: 0.3 }}
			className='min-h-screen bg-gray-900'
		>
			<div className='max-w-7xl mx-auto p-6'>
				{/* Progress indicator */}
				<div className='mb-8'>
					<div className='flex justify-between items-center mb-2'>
						<span className='text-sm text-gray-400'>
							Step {currentStep + 1} of {steps.length}
						</span>
						<span className='text-sm text-gray-400'>
							{Math.round(((currentStep + 1) / steps.length) * 100)}% Complete
						</span>
					</div>
					<div className='w-full bg-gray-700 rounded-full h-2'>
						<div
							className='bg-gradient-to-r from-blue-500 to-purple-600 h-2 rounded-full transition-all duration-300'
							style={{ width: `${((currentStep + 1) / steps.length) * 100}%` }}
						/>
					</div>
				</div>

				{/* Main content - Side by side */}
				<div className='grid lg:grid-cols-2 gap-8 mb-8'>
					{/* Left Panel */}
					<div className='bg-gray-800 rounded-2xl shadow-xl p-8 flex flex-col justify-center min-h-[600px] border border-gray-700'>
						<AnimatePresence mode='wait'>
							<motion.div
								key={currentStep}
								initial={{ opacity: 0, x: -20 }}
								animate={{ opacity: 1, x: 0 }}
								exit={{ opacity: 0, x: 20 }}
								transition={{ duration: 0.3 }}
							>
								{renderLeftPanel()}
							</motion.div>
						</AnimatePresence>
					</div>

					{/* Right Panel */}
					<div className='bg-gray-800 rounded-2xl shadow-xl p-8 min-h-[600px] border border-gray-700'>
						<AnimatePresence mode='wait'>
							<motion.div
								key={currentStep}
								initial={{ opacity: 0, x: 20 }}
								animate={{ opacity: 1, x: 0 }}
								exit={{ opacity: 0, x: -20 }}
								transition={{ duration: 0.3 }}
								className='h-full'
							>
								{renderRightPanel()}
							</motion.div>
						</AnimatePresence>
					</div>
				</div>

				{/* Navigation */}
				<div className='flex justify-between'>
					<button
						onClick={currentStep === 0 ? onBack : prevStep}
						disabled={currentStep === 0 || isProcessing}
						className='flex items-center gap-2 bg-gray-700 border border-gray-600 hover:border-gray-500 hover:bg-gray-600 px-6 py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-gray-300'
					>
						<ChevronLeft className='w-4 h-4' />
						Back
					</button>

					<button
						onClick={
							currentStep === steps.length - 1 ? handleFinalSelection : nextStep
						}
						disabled={
							isProcessing ||
							(steps[currentStep] === 'selection' && !selectedMethod) ||
							currentStep === steps.length - 1
						}
						className='flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed'
					>
						{currentStep === steps.length - 1
							? isProcessing
								? 'Creating Workspace...'
								: 'Create Workspace'
							: 'Continue'}
						<ChevronRight className='w-4 h-4' />
					</button>
				</div>
			</div>
		</motion.div>
	);
}
