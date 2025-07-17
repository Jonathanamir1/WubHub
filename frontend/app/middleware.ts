import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
	// Get the pathname
	const { pathname } = request.nextUrl;

	// Get the JWT token from cookies
	const token = request.cookies.get('auth_token')?.value;

	// Define route categories
	const isAuthRoute = pathname.startsWith('/auth');
	const isOnboardingRoute = pathname.startsWith('/onboarding');
	const isProtectedRoute =
		pathname.startsWith('/dashboard') ||
		pathname.startsWith('/projects') ||
		pathname.startsWith('/settings') ||
		pathname.startsWith('/workspace');
	const isRootRoute = pathname === '/';

	// Check if user is authenticated
	const isAuthenticated = !!token; // TODO: Add actual token validation

	// Handle root route
	if (isRootRoute) {
		if (isAuthenticated) {
			// Redirect authenticated users to dashboard
			// Note: Dashboard will handle onboarding redirect via useEffect
			return NextResponse.redirect(new URL('/dashboard', request.url));
		} else {
			// Redirect unauthenticated users to login
			return NextResponse.redirect(new URL('/auth/login', request.url));
		}
	}

	// Handle unauthenticated users accessing protected routes
	if ((isProtectedRoute || isOnboardingRoute) && !isAuthenticated) {
		// Redirect to login with return URL
		const loginUrl = new URL('/auth/login', request.url);
		loginUrl.searchParams.set('returnUrl', pathname);
		return NextResponse.redirect(loginUrl);
	}

	// Handle authenticated users accessing auth routes
	if (isAuthRoute && isAuthenticated) {
		// Redirect to dashboard (dashboard will handle onboarding redirect)
		return NextResponse.redirect(new URL('/dashboard', request.url));
	}

	// Allow onboarding routes for authenticated users
	// (The onboarding component will handle checking if they actually need onboarding)
	if (isOnboardingRoute && isAuthenticated) {
		return NextResponse.next();
	}

	// Allow protected routes for authenticated users
	// (Each protected route will check onboarding status via useOnboarding hook)
	if (isProtectedRoute && isAuthenticated) {
		return NextResponse.next();
	}

	// Allow the request to continue
	return NextResponse.next();
}

// Configure which routes to run middleware on
export const config = {
	matcher: [
		/*
		 * Match all request paths except for the ones starting with:
		 * - api (API routes)
		 * - _next/static (static files)
		 * - _next/image (image optimization files)
		 * - favicon.ico (favicon file)
		 * - public files (images, etc)
		 */
		'/((?!api|_next/static|_next/image|favicon.ico|.*\\.).*)',
	],
};
