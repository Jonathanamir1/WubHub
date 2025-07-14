// app/lib/providers.tsx
'use client';

import { HeroUIProvider } from '@heroui/react';
import { AuthProvider } from '../hooks/useAuth';

export function Providers({ children }: { children: React.ReactNode }) {
	return (
		<HeroUIProvider>
			<AuthProvider>{children}</AuthProvider>
		</HeroUIProvider>
	);
}
