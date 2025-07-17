// app/onboarding/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '../hooks/useAuth';
import { useOnboarding, useOnboardingStatus } from '../hooks/useOnboarding';
import { CreateWorkspaceRequest } from '../lib/onboarding';
import WubHubOnboarding from './components/WubHubOnboarding';
import WorkspaceCreationForm from './components/WorkspaceCreationForm';
import OnboardingComplete from './components/OnboardingComplete';

type OnboardingStep =
	| 'welcome'
	| 'workspace_selection'
	| 'workspace_creation'
	| 'complete';

export default function OnboardingPage() {
	const { user } = useAuth();
	const { needsOnboarding, isCompleted, isLoading } = useOnboardingStatus();
	const { startOnboarding, createFirstWorkspace, error, clearError } =
		useOnboarding();
	const router = useRouter();

	const [currentStep, setCurrentStep] = useState<OnboardingStep>(
		'workspace_selection'
	);
	const [selectedWorkspaceType, setSelectedWorkspaceType] = useState<
		'project_based' | 'client_based' | 'library' | null
	>(null);
	const [isProcessing, setIsProcessing] = useState(false);
	const [createdWorkspace, setCreatedWorkspace] = useState<any>(null);

	// Check if user actually needs onboarding
	useEffect(() => {
		if (!isLoading && !needsOnboarding && isCompleted) {
			console.log(
				'🔄 User has completed onboarding, redirecting to dashboard...'
			);
			router.push('/dashboard');
		}
	}, [needsOnboarding, isCompleted, isLoading, router]);

	// Handle welcome step - start onboarding
	const handleStartOnboarding = async () => {
		try {
			setIsProcessing(true);
			clearError();

			await startOnboarding();
			setCurrentStep('workspace_type');
		} catch (error) {
			console.error('Failed to start onboarding:', error);
			// Error is handled by useOnboarding hook
		} finally {
			setIsProcessing(false);
		}
	};

	// Handle workspace type selection from the integrated component
	const handleWorkspaceSelection = async (
		type: 'project_based' | 'client_based' | 'library'
	) => {
		setSelectedWorkspaceType(type);
		setCurrentStep('workspace_creation');
	};

	// Handle workspace creation
	const handleCreateWorkspace = async (
		workspaceData: CreateWorkspaceRequest
	) => {
		try {
			setIsProcessing(true);
			clearError();

			const workspace = await createFirstWorkspace(workspaceData);
			setCreatedWorkspace(workspace);
			setCurrentStep('complete');
		} catch (error) {
			console.error('Failed to create workspace:', error);
			// Error is handled by useOnboarding hook
		} finally {
			setIsProcessing(false);
		}
	};

	// Handle back navigation
	const handleBack = () => {
		if (currentStep === 'workspace_creation') {
			setCurrentStep('workspace_selection');
			setSelectedWorkspaceType(null);
		}
	};

	// Handle completion
	const handleComplete = () => {
		router.push('/dashboard');
	};

	// Show loading if checking onboarding status
	if (isLoading) {
		return (
			<div className='min-h-screen bg-gray-900 flex items-center justify-center'>
				<motion.div
					className='text-center'
					initial={{ opacity: 0, y: 20 }}
					animate={{ opacity: 1, y: 0 }}
					transition={{ duration: 0.5 }}
				>
					<motion.div
						className='w-16 h-16 bg-gradient-to-br from-purple-500 to-blue-600 rounded-xl flex items-center justify-center mx-auto mb-4'
						animate={{
							scale: [1, 1.1, 1],
							rotate: [0, 5, -5, 0],
						}}
						transition={{
							duration: 2,
							repeat: Infinity,
							ease: 'easeInOut',
						}}
					>
						<span className='text-white text-3xl font-bold'>W</span>
					</motion.div>
					<motion.div
						className='w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full mx-auto'
						animate={{ rotate: 360 }}
						transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
					/>
					<p className='text-gray-400 mt-4'>Loading onboarding...</p>
				</motion.div>
			</div>
		);
	}

	// Don't render if user doesn't need onboarding (will redirect)
	if (!needsOnboarding && isCompleted) {
		return null;
	}

	return (
		<div className='min-h-screen bg-gray-900 flex items-center justify-center p-4'>
			<motion.div
				className='w-full'
				initial={{ opacity: 0, y: 20 }}
				animate={{ opacity: 1, y: 0 }}
				transition={{ duration: 0.5 }}
			>
				{/* Progress Indicator */}
				<div className='flex justify-center mb-8'>
					<div className='flex space-x-2'>
						{['workspace_selection', 'workspace_creation', 'complete'].map(
							(step, index) => (
								<div
									key={step}
									className={`w-3 h-3 rounded-full transition-colors ${
										[
											'workspace_selection',
											'workspace_creation',
											'complete',
										].indexOf(currentStep) >= index
											? 'bg-blue-500'
											: 'bg-gray-600'
									}`}
								/>
							)
						)}
					</div>
				</div>

				{/* Error Display */}
				<AnimatePresence>
					{error && (
						<motion.div
							className='mb-6 p-4 bg-red-900/50 border border-red-700 rounded-lg'
							initial={{ opacity: 0, y: -10 }}
							animate={{ opacity: 1, y: 0 }}
							exit={{ opacity: 0, y: -10 }}
						>
							<p className='text-red-300 text-sm'>{error}</p>
						</motion.div>
					)}
				</AnimatePresence>

				{/* Step Content */}
				<AnimatePresence mode='wait'>
					{currentStep === 'workspace_selection' && (
						<WubHubOnboarding
							onSelect={handleWorkspaceSelection}
							onBack={() => router.push('/dashboard')}
							isProcessing={isProcessing}
						/>
					)}

					{currentStep === 'workspace_creation' && selectedWorkspaceType && (
						<WorkspaceCreationForm
							workspaceType={selectedWorkspaceType}
							onSubmit={handleCreateWorkspace}
							onBack={handleBack}
							isProcessing={isProcessing}
						/>
					)}

					{currentStep === 'complete' && createdWorkspace && (
						<OnboardingComplete
							workspace={createdWorkspace}
							onComplete={handleComplete}
						/>
					)}
				</AnimatePresence>
			</motion.div>
		</div>
	);
}
