import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/api';

// Import icons
import { FiFolder, FiClock, FiMusic, FiAlertCircle } from 'react-icons/fi';

// Import components
import Spinner from '../components/common/Spinner';

const DashboardPage = () => {
	const { currentUser } = useAuth();
	const [recentProjects, setRecentProjects] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [activeTab, setActiveTab] = useState('recent');

	useEffect(() => {
		const fetchRecentProjects = async () => {
			try {
				setLoading(true);

				// Try to fetch recent projects
				try {
					const recentProjectsResponse = await api.getRecentProjects();
					console.log('Recent projects response:', recentProjectsResponse.data);
					setRecentProjects(recentProjectsResponse.data || []);
				} catch (projectsErr) {
					console.error('Projects fetch error:', projectsErr);
					console.error('Projects error response:', projectsErr.response?.data);
					setRecentProjects([]);
				}

				setError(null);
			} catch (err) {
				console.error('Error fetching dashboard data:', err);
				setError(`Failed to load dashboard data: ${err.message}`);
			} finally {
				setLoading(false);
			}
		};

		fetchRecentProjects();
	}, []);

	// Loading state
	if (loading) {
		return (
			<div className='min-h-screen flex items-center justify-center bg-ableton-dark-400'>
				<div className='flex flex-col items-center'>
					<Spinner
						size='lg'
						color='blue'
					/>
					<p className='text-gray-400 mt-4'>Loading your dashboard...</p>
				</div>
			</div>
		);
	}

	// Error state
	if (error) {
		return (
			<div className='min-h-screen flex items-center justify-center bg-ableton-dark-400 px-4'>
				<div className='bg-red-500/10 border border-red-500/30 rounded-lg p-4 max-w-md w-full'>
					<h2 className='text-red-500 text-lg font-semibold mb-2 flex items-center'>
						<FiAlertCircle className='w-5 h-5 mr-2' />
						Error Loading Dashboard
					</h2>
					<p className='text-gray-300'>{error}</p>
					<button
						className='mt-4 px-4 py-2 bg-ableton-dark-300 text-white rounded-md hover:bg-ableton-dark-200 transition-colors'
						onClick={() => window.location.reload()}
					>
						Try Again
					</button>
				</div>
			</div>
		);
	}

	return (
		<div className='min-h-screen bg-ableton-dark-400 text-gray-200'>
			<main>
				<div className='container mx-auto px-4 py-8 max-w-7xl'>
					{/* Dashboard Header */}
					<div className='flex flex-col md:flex-row md:items-center md:justify-between mb-8'>
						<div>
							<h1 className='text-2xl md:text-3xl font-bold text-white'>
								Dashboard
							</h1>
							<p className='text-gray-400 mt-1'>
								Welcome back, {currentUser?.username || 'User'}
							</p>
						</div>
					</div>
				</div>
			</main>
		</div>
	);
};

export default DashboardPage;
