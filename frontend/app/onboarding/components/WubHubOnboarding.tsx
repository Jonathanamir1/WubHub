'use client';

import { useState } from 'react';
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

	const steps = [
		'welcome',
		'explanation',
		'methods',
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

	const handleFinalSelection = async () => {
		if (selectedMethod) {
			await onSelect(selectedMethod);
		}
	};

	const renderWelcome = () => (
		<motion.div
			className='text-center space-y-6'
			initial={{ opacity: 0, y: 20 }}
			animate={{ opacity: 1, y: 0 }}
			transition={{ duration: 0.5 }}
		>
			<div className='w-20 h-20 bg-gradient-to-br from-blue-500 to-purple-600 rounded-2xl mx-auto flex items-center justify-center'>
				<Music className='w-10 h-10 text-white' />
			</div>
			<div>
				<h1 className='text-3xl font-bold mb-2 text-white'>
					Welcome to WubHub
				</h1>
				<p className='text-gray-300 text-lg'>
					Let's set up your workspace to match how you create music
				</p>
			</div>
			<div className='bg-gray-800 rounded-lg p-6 border border-gray-700'>
				<h3 className='font-semibold mb-2 text-white'>
					🎯 Smart File Organization
				</h3>
				<p className='text-sm text-gray-400'>
					WubHub automatically organizes your files based on how you work. Just
					drag and drop - we'll handle the rest.
				</p>
			</div>
		</motion.div>
	);

	const renderExplanation = () => (
		<motion.div
			className='space-y-6'
			initial={{ opacity: 0, y: 20 }}
			animate={{ opacity: 1, y: 0 }}
			transition={{ duration: 0.5 }}
		>
			<div className='text-center'>
				<h2 className='text-2xl font-bold mb-2 text-white'>How WubHub Works</h2>
				<p className='text-gray-300'>
					WubHub creates intelligent views of your files based on your workflow
				</p>
			</div>

			<div className='grid gap-4'>
				<div className='border-2 border-dashed border-blue-500/30 bg-blue-500/10 rounded-lg'>
					<div className='p-6'>
						<div className='flex items-center gap-3 mb-3'>
							<Upload className='w-5 h-5 text-blue-400' />
							<span className='font-semibold text-white'>
								1. Drop Your Files
							</span>
						</div>
						<p className='text-sm text-gray-400'>
							Drag your files and folders directly into your desired workspace
						</p>
					</div>
				</div>

				<div className='border-2 border-dashed border-green-500/30 bg-green-500/10 rounded-lg'>
					<div className='p-6'>
						<div className='flex items-center gap-3 mb-3'>
							<Zap className='w-5 h-5 text-green-400' />
							<span className='font-semibold text-white'>2. Smart Views</span>
						</div>
						<p className='text-sm text-gray-400'>
							WubHub automatically creates the right view for your workflow
						</p>
					</div>
				</div>

				<div className='border-2 border-dashed border-purple-500/30 bg-purple-500/10 rounded-lg'>
					<div className='p-6'>
						<div className='flex items-center gap-3 mb-3'>
							<Folder className='w-5 h-5 text-purple-400' />
							<span className='font-semibold text-white'>
								3. Creative Focus
							</span>
						</div>
						<p className='text-sm text-gray-400'>
							Navigate the app through magic mode, or switch to browse, share,
							and edit your files normally.
						</p>
					</div>
				</div>
			</div>
		</motion.div>
	);

	const renderMethods = () => (
		<motion.div
			className='space-y-6'
			initial={{ opacity: 0, y: 20 }}
			animate={{ opacity: 1, y: 0 }}
			transition={{ duration: 0.5 }}
		>
			<div className='text-center'>
				<h2 className='text-2xl font-bold mb-2 text-white'>
					Choose Your Organization Style
				</h2>
				<p className='text-gray-300'>
					Pick the method that matches how you work with music
				</p>
			</div>

			<div className='space-y-4'>
				{organizationMethods.map((method) => {
					const IconComponent = method.icon;
					return (
						<motion.div
							key={method.id}
							className={`cursor-pointer transition-all hover:border-gray-600 bg-gray-800 border rounded-xl ${
								selectedMethod === method.id
									? 'ring-2 ring-blue-500 bg-blue-500/10 border-blue-500'
									: 'border-gray-700'
							}`}
							onClick={() =>
								setSelectedMethod(
									method.id as 'project_based' | 'client_based' | 'library'
								)
							}
							whileHover={{ scale: 1.02 }}
							whileTap={{ scale: 0.98 }}
						>
							<div className='p-4'>
								<div className='flex items-center gap-3 mb-3'>
									<div
										className={`w-10 h-10 ${method.color} rounded-lg flex items-center justify-center`}
									>
										<IconComponent className='w-5 h-5 text-white' />
									</div>
									<div>
										<h3 className='text-lg font-semibold text-white'>
											{method.title}
										</h3>
										<p className='text-gray-400 text-sm'>
											{method.description}
										</p>
									</div>
								</div>
							</div>
							<div className='px-4 pb-4'>
								<div className='space-y-3'>
									<div className='text-sm font-medium text-gray-300'>
										File Structure:
									</div>
									<div className='flex flex-wrap gap-2'>
										{method.levels.map((level, index) => (
											<div
												key={index}
												className='flex items-center gap-1'
											>
												<span className='px-2 py-1 bg-gray-700 text-gray-300 rounded text-xs border border-gray-600'>
													{level.name}
												</span>
												{index < method.levels.length - 1 && (
													<ChevronRight className='w-3 h-3 text-gray-500' />
												)}
											</div>
										))}
									</div>
									<div className='text-xs text-gray-400 bg-gray-700/50 rounded p-2 border border-gray-600'>
										<strong>Best for:</strong> {method.useCase}
									</div>
								</div>
							</div>
						</motion.div>
					);
				})}
			</div>
		</motion.div>
	);

	const renderSelection = () => {
		const selected = organizationMethods.find((m) => m.id === selectedMethod);
		if (!selected) return null;

		const IconComponent = selected.icon;

		return (
			<motion.div
				className='space-y-6'
				initial={{ opacity: 0, y: 20 }}
				animate={{ opacity: 1, y: 0 }}
				transition={{ duration: 0.5 }}
			>
				<div className='text-center'>
					<h2 className='text-2xl font-bold mb-2 text-white'>
						Your Organization Preview
					</h2>
					<p className='text-gray-300'>
						Here's how your files will be organized with {selected.title}
					</p>
				</div>

				<div className='bg-gradient-to-br from-blue-500/10 to-purple-500/10 border-2 border-gray-700 rounded-xl'>
					<div className='p-6'>
						<div className='flex items-center gap-3 mb-6'>
							<div
								className={`w-12 h-12 ${selected.color} rounded-xl flex items-center justify-center`}
							>
								<IconComponent className='w-6 h-6 text-white' />
							</div>
							<div>
								<h3 className='font-semibold text-white'>{selected.title}</h3>
								<p className='text-gray-400 text-sm'>{selected.description}</p>
							</div>
						</div>

						<div className='space-y-4'>
							<div className='text-sm font-semibold text-white'>
								File Hierarchy:
							</div>
							{selected.levels.map((level, index) => {
								const LevelIcon = level.icon;
								return (
									<div
										key={index}
										className='flex items-center gap-3 pl-4'
										style={{ marginLeft: `${index * 20}px` }}
									>
										<div className='w-8 h-8 bg-gray-700 rounded-lg flex items-center justify-center border border-gray-600'>
											<LevelIcon className='w-4 h-4 text-gray-300' />
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

						<div className='mt-6 p-4 bg-gray-800/80 rounded-lg border border-gray-600'>
							<div className='text-sm font-semibold mb-2 text-white'>
								💡 How it works:
							</div>
							<p className='text-xs text-gray-400'>
								When you drop files, WubHub will automatically create this
								structure. You can always change your organization method later
								in settings.
							</p>
						</div>
					</div>
				</div>
			</motion.div>
		);
	};

	const renderConfirmation = () => {
		const selected = organizationMethods.find((m) => m.id === selectedMethod);
		if (!selected) return null;

		return (
			<motion.div
				className='text-center space-y-6'
				initial={{ opacity: 0, y: 20 }}
				animate={{ opacity: 1, y: 0 }}
				transition={{ duration: 0.5 }}
			>
				<div className='w-20 h-20 bg-gradient-to-br from-green-500 to-blue-600 rounded-2xl mx-auto flex items-center justify-center'>
					<Music className='w-10 h-10 text-white' />
				</div>
				<div>
					<h1 className='text-3xl font-bold mb-2 text-white'>
						You're All Set! 🎉
					</h1>
					<p className='text-gray-300 text-lg'>
						Your workspace is configured with {selected.title}
					</p>
				</div>
				<div className='bg-gradient-to-r from-blue-500/10 to-purple-500/10 border border-gray-700 rounded-xl'>
					<div className='p-6'>
						<h3 className='font-semibold mb-3 text-white'>
							Ready to start creating?
						</h3>
						<div className='space-y-2 text-sm text-gray-400'>
							<p>✨ Drop your first audio files to see the magic happen</p>
							<p>
								🎵 Your files will automatically organize into the perfect
								structure
							</p>
							<p>
								⚙️ You can always change your organization method in settings
							</p>
						</div>
					</div>
				</div>
			</motion.div>
		);
	};

	const renderCurrentStep = () => {
		switch (steps[currentStep]) {
			case 'welcome':
				return renderWelcome();
			case 'explanation':
				return renderExplanation();
			case 'methods':
				return renderMethods();
			case 'selection':
				return renderSelection();
			case 'confirmation':
				return renderConfirmation();
			default:
				return renderWelcome();
		}
	};

	return (
		<motion.div
			initial={{ opacity: 0, y: 20 }}
			animate={{ opacity: 1, y: 0 }}
			exit={{ opacity: 0, y: -20 }}
			transition={{ duration: 0.3 }}
			className='max-w-2xl mx-auto'
		>
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

			{/* Main content */}
			<div className='bg-gray-800 rounded-2xl border border-gray-700 p-8 mb-6'>
				<AnimatePresence mode='wait'>{renderCurrentStep()}</AnimatePresence>
			</div>

			{/* Navigation */}
			<div className='flex justify-between'>
				<motion.button
					onClick={currentStep === 0 ? onBack : prevStep}
					disabled={isProcessing}
					className='flex items-center gap-2 px-6 py-3 border border-gray-600 bg-gray-800 text-gray-300 hover:text-white hover:border-gray-500 rounded-lg transition-colors disabled:opacity-50'
					whileHover={{ scale: 1.05 }}
					whileTap={{ scale: 0.95 }}
				>
					<ChevronLeft className='w-4 h-4' />
					Back
				</motion.button>

				<motion.button
					onClick={
						currentStep === steps.length - 1 ? handleFinalSelection : nextStep
					}
					disabled={
						isProcessing ||
						(steps[currentStep] === 'methods' && !selectedMethod)
					}
					className='flex items-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed'
					whileHover={{ scale: 1.05 }}
					whileTap={{ scale: 0.95 }}
				>
					{isProcessing
						? 'Creating...'
						: currentStep === steps.length - 1
						? 'Create Workspace'
						: 'Continue'}
					<ChevronRight className='w-4 h-4' />
				</motion.button>
			</div>
		</motion.div>
	);
}
