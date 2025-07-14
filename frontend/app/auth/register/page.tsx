// app/auth/register/page.tsx
import AuthLayout from '../components/AuthLayout';
import SignupForm from '../components/SignupForm';

export default function SignupPage() {
	return (
		<AuthLayout
			title='Create your account'
			subtitle='Join WubHub and start organizing your music'
			footerText='Already have an account?'
			footerLinkText='Sign in'
			footerLinkHref='/auth/login'
		>
			<SignupForm />
		</AuthLayout>
	);
}
