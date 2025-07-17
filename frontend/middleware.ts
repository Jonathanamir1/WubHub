// frontend/middleware.ts (REMEMBER: ROOT LEVEL, NOT IN APP FOLDER)

import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
	// Get the pathname
	const { pathname } = request.nextUrl;

	console.log('🔍 MIDDLEWARE: Processing request for:', pathname);

	// Get the JWT token from cookies
	const token = request.cookies.get('auth_token')?.value;
	console.log('🔍 MIDDLEWARE: Token found:', !!token);

	// Define route categories
	const isAuthRoute = pathname.startsWith('/auth');
	const isOnboardingRoute = pathname.startsWith('/onboarding');
	const isProtectedRoute =
		pathname.startsWith('/dashboard') ||
		pathname.startsWith('/projects') ||
		pathname.startsWith('/settings') ||
		pathname.startsWith('/workspace');
	const isRootRoute = pathname === '/';

	console.log('🔍 MIDDLEWARE: Route type:', {
		isRootRoute,
		isAuthRoute,
		isProtectedRoute,
		isOnboardingRoute,
	});

	// Check if user is authenticated
	const isAuthenticated = !!token;
	console.log('🔍 MIDDLEWARE: User authenticated:', isAuthenticated);

	// Handle root route
	if (isRootRoute) {
		if (isAuthenticated) {
			// FIXED: Allow authenticated users to stay on homepage
			console.log(
				'✅ MIDDLEWARE: Authenticated user at root, allowing access to homepage'
			);
			return NextResponse.next();
		} else {
			// Redirect unauthenticated users to login
			console.log(
				'🔄 MIDDLEWARE: Unauthenticated user at root, redirecting to login'
			);
			const redirectUrl = new URL('/auth/login', request.url);
			console.log('🔄 MIDDLEWARE: Redirect URL:', redirectUrl.toString());
			return NextResponse.redirect(redirectUrl);
		}
	}

	// Handle unauthenticated users accessing protected routes
	if ((isProtectedRoute || isOnboardingRoute) && !isAuthenticated) {
		console.log(
			`🔒 MIDDLEWARE: Unauthenticated access to ${pathname}, redirecting to login`
		);
		// Redirect to login with return URL
		const loginUrl = new URL('/auth/login', request.url);
		loginUrl.searchParams.set('returnUrl', pathname);
		return NextResponse.redirect(loginUrl);
	}

	// Handle authenticated users accessing auth routes
	if (isAuthRoute && isAuthenticated) {
		console.log(
			'🔄 MIDDLEWARE: Authenticated user accessing auth route, redirecting to homepage'
		);
		// Redirect to homepage
		return NextResponse.redirect(new URL('/', request.url));
	}

	// Allow onboarding routes for authenticated users
	if (isOnboardingRoute && isAuthenticated) {
		console.log(
			'✅ MIDDLEWARE: Allowing onboarding route for authenticated user'
		);
		return NextResponse.next();
	}

	// Allow protected routes for authenticated users
	if (isProtectedRoute && isAuthenticated) {
		console.log(
			'✅ MIDDLEWARE: Allowing protected route for authenticated user'
		);
		return NextResponse.next();
	}

	// Allow the request to continue
	console.log('✅ MIDDLEWARE: Allowing request to continue');
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
