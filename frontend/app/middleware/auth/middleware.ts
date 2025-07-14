// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
	// Get the pathname
	const { pathname } = request.nextUrl;

	// Get the JWT token from cookies
	const token = request.cookies.get('auth_token')?.value;

	// Define protected and auth routes
	const isAuthRoute = pathname.startsWith('/auth');
	const isProtectedRoute =
		pathname.startsWith('/dashboard') ||
		pathname.startsWith('/projects') ||
		pathname.startsWith('/settings');
	const isRootRoute = pathname === '/';

	// Check if user is authenticated
	const isAuthenticated = !!token; // TODO: Add actual token validation

	// Handle root route
	if (isRootRoute) {
		if (isAuthenticated) {
			// Redirect authenticated users to dashboard
			return NextResponse.redirect(new URL('/dashboard', request.url));
		} else {
			// Redirect unauthenticated users to login
			return NextResponse.redirect(new URL('/auth/login', request.url));
		}
	}

	// Handle protected routes
	if (isProtectedRoute && !isAuthenticated) {
		// Redirect to login with return URL
		const loginUrl = new URL('/auth/login', request.url);
		loginUrl.searchParams.set('returnUrl', pathname);
		return NextResponse.redirect(loginUrl);
	}

	// Handle auth routes when already authenticated
	if (isAuthRoute && isAuthenticated) {
		// Redirect to dashboard if trying to access auth pages while logged in
		return NextResponse.redirect(new URL('/dashboard', request.url));
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
