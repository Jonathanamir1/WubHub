// app/lib/googleAuth.ts
declare global {
	interface Window {
		google: any;
	}
}

interface GoogleAuthResponse {
	credential: string;
	select_by: string;
}

class GoogleAuthService {
	private clientId =
		'227102122211-fcceudmgu7tbvh0ggc1gst0ippbr3jtj.apps.googleusercontent.com';
	private isInitialized = false;

	/**
	 * Initialize Google Sign-In
	 */
	async initialize(): Promise<void> {
		return new Promise((resolve, reject) => {
			// Check if already initialized
			if (this.isInitialized && window.google) {
				resolve();
				return;
			}

			// Load Google Identity Services script
			const script = document.createElement('script');
			script.src = 'https://accounts.google.com/gsi/client';
			script.async = true;
			script.defer = true;

			script.onload = () => {
				if (window.google) {
					this.isInitialized = true;
					resolve();
				} else {
					reject(new Error('Google Identity Services failed to load'));
				}
			};

			script.onerror = () => {
				reject(new Error('Failed to load Google Identity Services script'));
			};

			document.head.appendChild(script);
		});
	}

	/**
	 * Show Google Sign-In popup using the new method
	 */
	async signInWithPopup(): Promise<string> {
		await this.initialize();

		return new Promise((resolve, reject) => {
			try {
				window.google.accounts.oauth2
					.initTokenClient({
						client_id: this.clientId,
						scope: 'email profile',
						callback: async (response: any) => {
							if (response.access_token) {
								try {
									// Get user info using the access token
									const userInfoResponse = await fetch(
										`https://www.googleapis.com/oauth2/v2/userinfo?access_token=${response.access_token}`
									);

									if (userInfoResponse.ok) {
										const userInfo = await userInfoResponse.json();

										// Create a simple token for our backend
										const userToken = btoa(
											JSON.stringify({
												sub: userInfo.id,
												email: userInfo.email,
												name: userInfo.name,
												picture: userInfo.picture,
												email_verified: userInfo.verified_email,
												access_token: response.access_token,
											})
										);

										console.log('🔍 Frontend: Created user token with data:', {
											sub: userInfo.id,
											email: userInfo.email,
											name: userInfo.name,
											email_verified: userInfo.verified_email,
											token_length: userToken.length,
										});

										resolve(userToken);
									} else {
										reject(new Error('Failed to get user info from Google'));
									}
								} catch (error) {
									reject(new Error('Failed to process Google response'));
								}
							} else {
								reject(new Error('No access token received from Google'));
							}
						},
						error_callback: (error: any) => {
							reject(
								new Error(
									`Google authentication failed: ${
										error.message || 'Unknown error'
									}`
								)
							);
						},
					})
					.requestAccessToken();
			} catch (error) {
				reject(new Error(`Failed to initialize Google Sign-In: ${error}`));
			}
		});
	}

	/**
	 * Sign out from Google
	 */
	async signOut(): Promise<void> {
		if (window.google && window.google.accounts) {
			try {
				window.google.accounts.oauth2.revoke('', () => {
					console.log('Google sign-out successful');
				});
			} catch (error) {
				console.warn('Google sign-out failed:', error);
			}
		}
	}
}

export const googleAuthService = new GoogleAuthService();
