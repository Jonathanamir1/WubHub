// frontend/app/hooks/useOnboarding.ts

'use client';

import {
	useState,
	useEffect,
	useContext,
	createContext,
	createElement,
} from 'react';
import {
	onboardingService,
	OnboardingStatus,
	CreateWorkspaceRequest,
	WorkspaceResponse,
} from '../lib/onboarding';
import { useAuth } from './useAuth'; // ADDED: Import useAuth

// Types for the hook
interface OnboardingContextType {
	// Status
	status: OnboardingStatus | null;
	isLoading: boolean;
	error: string | null;

	// Actions
	startOnboarding: () => Promise<void>;
	createFirstWorkspace: (
		workspaceData: CreateWorkspaceRequest
	) => Promise<WorkspaceResponse>;
	completeOnboarding: () => Promise<void>;
	checkStatus: () => Promise<void>;
	clearError: () => void;
}

// Create context
const OnboardingContext = createContext<OnboardingContextType | undefined>(
	undefined
);

// Provider component
export function OnboardingProvider({
	children,
}: {
	children: React.ReactNode;
}) {
	const [status, setStatus] = useState<OnboardingStatus | null>(null);
	const [isLoading, setIsLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);

	// ADDED: Get auth status to prevent calling onboarding API when not authenticated
	const { isAuthenticated, isLoading: authLoading } = useAuth();

	/**
	 * Check onboarding status
	 */
	const checkStatus = async (): Promise<void> => {
		// ADDED: Don't check onboarding status if user is not authenticated
		if (!isAuthenticated) {
			console.log(
				'👤 User not authenticated, skipping onboarding status check'
			);
			setStatus(null);
			setIsLoading(false);
			return;
		}

		try {
			setIsLoading(true);
			setError(null);

			console.log('🔍 Checking onboarding status for authenticated user...');
			const statusResponse = await onboardingService.getStatus();
			setStatus(statusResponse);

			console.log('✅ Onboarding status loaded:', statusResponse);
		} catch (error: any) {
			console.error('❌ Failed to check onboarding status:', error);
			setError(error.message || 'Failed to check onboarding status');
		} finally {
			setIsLoading(false);
		}
	};

	/**
	 * Start onboarding process
	 */
	const startOnboarding = async (): Promise<void> => {
		if (!isAuthenticated) {
			throw new Error('Must be authenticated to start onboarding');
		}

		try {
			setIsLoading(true);
			setError(null);

			const response = await onboardingService.start();

			// Update status after starting
			await checkStatus();

			console.log('✅ Onboarding started:', response);
		} catch (error: any) {
			console.error('❌ Failed to start onboarding:', error);
			setError(error.message || 'Failed to start onboarding');
			throw error; // Re-throw for component handling
		} finally {
			setIsLoading(false);
		}
	};

	/**
	 * Create first workspace during onboarding
	 */
	const createFirstWorkspace = async (
		workspaceData: CreateWorkspaceRequest
	): Promise<WorkspaceResponse> => {
		if (!isAuthenticated) {
			throw new Error('Must be authenticated to create workspace');
		}

		try {
			setIsLoading(true);
			setError(null);

			const response = await onboardingService.createFirstWorkspace(
				workspaceData
			);

			// Update status after workspace creation
			await checkStatus();

			console.log('✅ First workspace created:', response);
			return response.workspace;
		} catch (error: any) {
			console.error('❌ Failed to create first workspace:', error);
			setError(error.message || 'Failed to create workspace');
			throw error; // Re-throw for component handling
		} finally {
			setIsLoading(false);
		}
	};

	/**
	 * Complete onboarding process
	 */
	const completeOnboarding = async (): Promise<void> => {
		if (!isAuthenticated) {
			throw new Error('Must be authenticated to complete onboarding');
		}

		try {
			setIsLoading(true);
			setError(null);

			const response = await onboardingService.complete();

			// Update status after completion
			await checkStatus();

			console.log('✅ Onboarding completed:', response);
		} catch (error: any) {
			console.error('❌ Failed to complete onboarding:', error);
			setError(error.message || 'Failed to complete onboarding');
			throw error; // Re-throw for component handling
		} finally {
			setIsLoading(false);
		}
	};

	/**
	 * Clear error state
	 */
	const clearError = (): void => {
		setError(null);
	};

	// UPDATED: Only check status when auth is loaded and user is authenticated
	useEffect(() => {
		if (!authLoading) {
			checkStatus();
		}
	}, [authLoading, isAuthenticated]); // ADDED: Dependencies on auth state

	const contextValue: OnboardingContextType = {
		status,
		isLoading,
		error,
		startOnboarding,
		createFirstWorkspace,
		completeOnboarding,
		checkStatus,
		clearError,
	};

	return createElement(
		OnboardingContext.Provider,
		{ value: contextValue },
		children
	);
}

/**
 * Hook to use onboarding context
 */
export function useOnboarding(): OnboardingContextType {
	const context = useContext(OnboardingContext);

	if (context === undefined) {
		throw new Error('useOnboarding must be used within an OnboardingProvider');
	}

	return context;
}

/**
 * Helper hooks for common onboarding checks
 */
export function useOnboardingStatus() {
	const { status, isLoading } = useOnboarding();

	return {
		needsOnboarding: status?.needs_onboarding ?? false,
		currentStep: status?.current_step ?? 'not_started',
		isCompleted: status?.current_step === 'completed',
		isLoading,
	};
}
