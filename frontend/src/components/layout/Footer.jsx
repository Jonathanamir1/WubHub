import React from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';

const Footer = () => {
	const { isAuthenticated } = useAuth();
	const currentYear = new Date().getFullYear();

	return (
		<footer
			className={`border-t border-ableton-dark-300 py-4 px-6 ${
				isAuthenticated ? 'ml-64' : ''
			}`}
		>
			<div className='flex flex-col md:flex-row justify-between items-center'>
				<div className='text-gray-400 text-sm mb-4 md:mb-0'>
					&copy; {currentYear} WubHub - Version Control for Musicians
				</div>

				<div className='flex space-x-6'>
					<Link
						to='#'
						className='text-gray-400 hover:text-ableton-blue-400 text-sm'
					>
						Terms of Service
					</Link>
					<Link
						to='#'
						className='text-gray-400 hover:text-ableton-blue-400 text-sm'
					>
						Privacy Policy
					</Link>
					<Link
						to='#'
						className='text-gray-400 hover:text-ableton-blue-400 text-sm'
					>
						Contact
					</Link>
				</div>
			</div>
		</footer>
	);
};

export default Footer;
