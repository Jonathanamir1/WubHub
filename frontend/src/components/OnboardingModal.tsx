// src/components/OnboardingModal.tsx
'use client';

import { useState } from 'react';
import { createWorkspace, completeOnboarding, skipOnboarding } from '@/lib/api';

interface OnboardingModalProps {
	isOpen: boolean;
	onComplete: () => void;
	onWorkspaceCreated: (workspace: any) => void;
	isFirstTime?: boolean; // New prop to distinguish first-time vs add workspace
}

interface Template {
	id: string;
	name: string;
	description: string;
	icon: string;
	features: string[];
}

const TEMPLATES: Template[] = [
	{
		id: 'songwriter',
		name: 'Songwriter',
		description:
			'Perfect for writing lyrics, chord progressions, and song structures',
		icon: '✍️',
		features: [
			'Lyric writing tools',
			'Chord progression tracking',
			'Song structure templates',
			'Voice memo organization',
			'Rhyme and idea notebooks',
		],
	},
	{
		id: 'producer',
		name: 'Producer',
		description: 'Organize beats, samples, and production workflows',
		icon: '🎛️',
		features: [
			'Beat and sample libraries',
			'Project version control',
			'Collaboration tools',
			'Mix session tracking',
			'Client project management',
		],
	},
	{
		id: 'mixing_engineer',
		name: 'Mixing Engineer',
		description: 'Manage mixing sessions, revisions, and client feedback',
		icon: '🎚️',
		features: [
			'Mix revision tracking',
			'Client feedback system',
			'Session file organization',
			'Reference track library',
			'Mix notes and settings',
		],
	},
	{
		id: 'mastering_engineer',
		name: 'Mastering Engineer',
		description: 'Handle mastering projects and client deliverables',
		icon: '🎭',
		features: [
			'Master version control',
			'Format delivery tracking',
			'Client specifications',
			'Reference monitoring',
			'Quality control checklists',
		],
	},
	{
		id: 'artist',
		name: 'Recording Artist',
		description: 'Manage your music career, releases, and creative projects',
		icon: '🎤',
		features: [
			'Release planning',
			'Creative project tracking',
			'Collaboration coordination',
			'Performance preparation',
			'Fan content organization',
		],
	},
	{
		id: 'other',
		name: 'Other',
		description: 'Start with a blank workspace and customize as needed',
		icon: '🎵',
		features: [
			'Flexible organization',
			'Custom workflows',
			'Adaptable structure',
			'General music tools',
			'Build your own system',
		],
	},
];

export default function OnboardingModal({
	isOpen,
	onComplete,
	onWorkspaceCreated,
	isFirstTime = false,
}: OnboardingModalProps) {
	const [currentStep, setCurrentStep] = useState(1);
	const [selectedTemplate, setSelectedTemplate] = useState<Template | null>(
		null
	);
	const [workspaceName, setWorkspaceName] = useState('');
	const [workspaceDescription, setWorkspaceDescription] = useState('');
	const [isCreating, setIsCreating] = useState(false);

	if (!isOpen) return null;

	const handleTemplateSelect = (template: Template) => {
		setSelectedTemplate(template);
		setWorkspaceName(`My ${template.name} Workspace`);
		setWorkspaceDescription(template.description);
		setCurrentStep(2);
	};

	const handleCreateWorkspace = async () => {
		if (!selectedTemplate) return;

		console.log('Creating workspace with template:', selectedTemplate.id);
		setIsCreating(true);
		const token = localStorage.getItem('wubhub_token');
		if (!token) {
			console.error('No token found');
			setIsCreating(false);
			return;
		}

		try {
			console.log('Calling createWorkspace API...');
			const result = await createWorkspace(token, {
				name: workspaceName,
				description: workspaceDescription,
				metadata: {
					template_type: selectedTemplate.id,
				},
			});

			console.log('Workspace creation result:', result);

			if (result.success) {
				console.log('Workspace created successfully:', result.data);

				// Mark onboarding as completed IMMEDIATELY if this is first time
				if (isFirstTime) {
					console.log('Marking onboarding as completed...');
					localStorage.setItem('wubhub_onboarding_completed', 'true');
				}

				// Update parent component with new workspace
				onWorkspaceCreated(result.data);

				console.log('Calling onComplete...');
				onComplete();
			} else {
				console.error('Failed to create workspace:', result.error);
				alert(`Failed to create workspace: ${result.error}`);
			}
		} catch (error) {
			console.error('Failed to create workspace:', error);
			alert(`Network error: ${error.message}`);
		} finally {
			setIsCreating(false);
		}
	};

	const handleSkipOnboarding = async () => {
		if (!isFirstTime) return; // Skip only available for first-time users

		console.log('Skipping onboarding...');

		// Mark as completed in localStorage immediately
		localStorage.setItem('wubhub_onboarding_completed', 'true');

		console.log('Onboarding skipped, calling onComplete...');
		onComplete();
	};

	const handleBack = () => {
		setCurrentStep(1);
		setSelectedTemplate(null);
	};

	return (
		<div
			className='fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center p-4 z-50'
			onClick={!isFirstTime ? onComplete : undefined} // Allow clicking outside to close if not first time
		>
			<div
				className='bg-dark-800 rounded-lg border border-dark-600 w-full max-w-4xl max-h-[90vh] overflow-y-auto relative'
				onClick={(e) => e.stopPropagation()} // Prevent modal from closing when clicking inside
			>
				{/* Close button - only show if not first time */}
				{!isFirstTime && (
					<button
						onClick={onComplete}
						className='absolute top-4 right-4 w-8 h-8 rounded-md bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-dark-300 hover:text-white transition-colors z-10'
						title='Close'
					>
						<svg
							width='16'
							height='16'
							viewBox='0 0 24 24'
							fill='none'
							stroke='currentColor'
							strokeWidth='2'
						>
							<path d='M18 6L6 18M6 6l12 12' />
						</svg>
					</button>
				)}
				{currentStep === 1 && (
					<div className='p-8'>
						{/* Welcome Header */}
						<div className='text-center mb-8'>
							<div className='text-6xl mb-4'>🎵</div>
							<h1 className='text-3xl font-bold text-white mb-2'>
								{isFirstTime ? 'Welcome to WubHub!' : 'Create New Workspace'}
							</h1>
							<p className='text-dark-300 text-lg'>
								{isFirstTime
									? "Let's set up your first workspace. Choose a template that matches your workflow:"
									: 'Choose a template for your new workspace:'}
							</p>
						</div>

						{/* Template Grid */}
						<div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4'>
							{TEMPLATES.map((template) => (
								<button
									key={template.id}
									onClick={() => handleTemplateSelect(template)}
									className='card p-6 text-left hover:border-accent-blue hover:bg-dark-700 transition-all group'
								>
									<div className='text-3xl mb-3'>{template.icon}</div>
									<h3 className='text-lg font-semibold text-white mb-2 group-hover:text-accent-blue'>
										{template.name}
									</h3>
									<p className='text-dark-400 text-sm mb-4'>
										{template.description}
									</p>
									<ul className='space-y-1'>
										{template.features.slice(0, 3).map((feature, index) => (
											<li
												key={index}
												className='text-xs text-dark-500 flex items-center gap-2'
											>
												<span className='w-1 h-1 bg-accent-blue rounded-full'></span>
												{feature}
											</li>
										))}
										{template.features.length > 3 && (
											<li className='text-xs text-dark-500 flex items-center gap-2'>
												<span className='w-1 h-1 bg-accent-blue rounded-full'></span>
												+{template.features.length - 3} more features
											</li>
										)}
									</ul>
								</button>
							))}
						</div>

						{/* Footer */}
						<div className='flex items-center justify-between mt-8'>
							<div className='text-sm text-dark-400'>
								{isFirstTime
									? "Don't worry - you can always create additional workspaces with different templates later!"
									: 'You can always change your workspace structure after creation.'}
							</div>

							{/* Skip button - only for first-time users */}
							{isFirstTime && (
								<button
									onClick={handleSkipOnboarding}
									className='text-sm text-dark-400 hover:text-white transition-colors'
								>
									Skip for now
								</button>
							)}
						</div>
					</div>
				)}

				{currentStep === 2 && selectedTemplate && (
					<div className='p-8'>
						{/* Header */}
						<div className='flex items-center gap-4 mb-8'>
							<button
								onClick={handleBack}
								className='w-8 h-8 rounded-md bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-dark-300 hover:text-white transition-colors'
							>
								<svg
									width='16'
									height='16'
									viewBox='0 0 24 24'
									fill='none'
									stroke='currentColor'
									strokeWidth='2'
								>
									<path d='M19 12H5m7 7-7-7 7-7' />
								</svg>
							</button>
							<div>
								<h2 className='text-2xl font-bold text-white'>
									{selectedTemplate.icon} {selectedTemplate.name} Workspace
								</h2>
								<p className='text-dark-400'>
									Customize your workspace details
								</p>
							</div>
						</div>

						<div className='grid grid-cols-1 lg:grid-cols-2 gap-8'>
							{/* Left Column - Form */}
							<div className='space-y-6'>
								<div>
									<label
										htmlFor='workspace-name'
										className='block text-sm font-medium text-accent-blue mb-2'
									>
										Workspace Name*
									</label>
									<input
										type='text'
										id='workspace-name'
										value={workspaceName}
										onChange={(e) => setWorkspaceName(e.target.value)}
										className='form-input'
										placeholder='My Songwriter Workspace'
									/>
								</div>

								<div>
									<label
										htmlFor='workspace-description'
										className='block text-sm font-medium text-accent-blue mb-2'
									>
										Description
									</label>
									<textarea
										id='workspace-description'
										value={workspaceDescription}
										onChange={(e) => setWorkspaceDescription(e.target.value)}
										className='form-input resize-none'
										rows={4}
										placeholder="Describe what you'll use this workspace for..."
									/>
								</div>

								<div className='flex gap-3 pt-4'>
									<button
										onClick={handleBack}
										className='btn-secondary flex-1'
									>
										Change Template
									</button>
									<button
										onClick={handleCreateWorkspace}
										disabled={isCreating || !workspaceName.trim()}
										className='btn-primary flex-1 disabled:opacity-50'
									>
										{isCreating ? 'Creating Workspace...' : 'Create Workspace'}
									</button>
								</div>
							</div>

							{/* Right Column - Template Info */}
							<div className='bg-dark-700 rounded-lg p-6'>
								<h3 className='text-lg font-semibold text-white mb-4'>
									What you'll get with {selectedTemplate.name}:
								</h3>
								<ul className='space-y-3'>
									{selectedTemplate.features.map((feature, index) => (
										<li
											key={index}
											className='flex items-start gap-3 text-dark-300'
										>
											<span className='w-5 h-5 bg-accent-blue rounded-full flex items-center justify-center text-dark-900 text-xs font-bold mt-0.5'>
												✓
											</span>
											{feature}
										</li>
									))}
								</ul>

								<div className='mt-6 p-4 bg-dark-600 rounded-md'>
									<div className='text-sm text-dark-400'>
										<strong className='text-white'>Note:</strong> You can
										customize your workspace structure at any time after
										creation. Templates just give you a head start!
									</div>
								</div>
							</div>
						</div>
					</div>
				)}
			</div>
		</div>
	);
}
