// app/auth/login/page.tsx
import AuthLayout from '../components/AuthLayout';
import LoginForm from '../components/LoginForm';

export default function LoginPage() {
	return (
		<AuthLayout
			title='Log into your account'
			footerText="Don't have an account?"
			footerLinkText='Sign up'
			footerLinkHref='/auth/register'
		>
			<LoginForm />
		</AuthLayout>
	);
}
