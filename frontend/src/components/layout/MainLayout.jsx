import React from 'react';
import { Outlet } from 'react-router-dom';
import Header from './Header';
import Footer from './Footer';
import Sidebar from './Sidebar';
import { useAuth } from '../../contexts/AuthContext';

const MainLayout = () => {
	const { isAuthenticated } = useAuth();

	return (
		<div className='flex flex-col min-h-screen bg-ableton-dark-400'>
			{/* <Header /> */}

			<div className='flex flex-1'>
				{isAuthenticated && <Sidebar />}

				<main className={`flex-1 ${isAuthenticated ? 'ml-64' : ''} pt-16`}>
					<div className='max-w-7xl mx-auto px-4 sm:px-6 py-8'>
						<Outlet />
					</div>
				</main>
			</div>

			<Footer />
		</div>
	);
};

export default MainLayout;
