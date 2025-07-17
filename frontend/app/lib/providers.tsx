'use client';

import { HeroUIProvider } from '@heroui/react';
import { AuthProvider } from '../hooks/useAuth';
import { OnboardingProvider } from '../hooks/useOnboarding';

export function Providers({ children }: { children: React.ReactNode }) {
	return (
		<HeroUIProvider>
			<AuthProvider>
				<OnboardingProvider>{children}</OnboardingProvider>
			</AuthProvider>
		</HeroUIProvider>
	);
}
