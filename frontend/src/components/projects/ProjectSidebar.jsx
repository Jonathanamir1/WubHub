// frontend/src/components/projects/ProjectSidebar.jsx
import React from 'react';
import {
	FiHome,
	FiFileText,
	FiMusic,
	FiHardDrive,
	FiSettings,
	FiUsers,
	FiClock,
	FiPlus,
} from 'react-icons/fi';

const ProjectSidebar = ({
	project,
	activeTab,
	setActiveTab,
	versions,
	selectedVersion,
	setSelectedVersion,
	collaborators,
	isOwner,
	onCreateVersion,
}) => {
	if (!project) return null;

	const getNavItemClass = (tab) => {
		return `flex items-center py-2 px-3 rounded-md transition-colors ${
			activeTab === tab
				? 'bg-ableton-dark-200 text-white'
				: 'text-gray-400 hover:bg-ableton-dark-200/50 hover:text-gray-300'
		}`;
	};

	// Get nav items based on project type
	const getProjectTypeNavItems = () => {
		const navItems = [];

		switch (project.project_type) {
			case 'songwriting':
				navItems.push({
					id: 'songwriting',
					label: 'Songwriting',
					icon: <FiFileText className='w-4 h-4 mr-2' />,
				});
				break;

			case 'production':
				navItems.push({
					id: 'production',
					label: 'Production',
					icon: <FiMusic className='w-4 h-4 mr-2' />,
				});
				break;

			case 'mixing':
				navItems.push({
					id: 'mixing',
					label: 'Mixing',
					icon: <FiMusic className='w-4 h-4 mr-2' />,
				});
				break;

			case 'mastering':
				navItems.push({
					id: 'mastering',
					label: 'Mastering',
					icon: <FiMusic className='w-4 h-4 mr-2' />,
				});
				break;

			default:
				// No specific tabs for other project types
				break;
		}

		return navItems;
	};

	const projectTypeNavItems = getProjectTypeNavItems();

	return (
		<div className='space-y-6'>
			{/* Project navigation */}
			<div>
				<h3 className='text-xs uppercase text-gray-500 font-medium mb-2 px-3'>
					Project
				</h3>

				<div className='space-y-1'>
					<button
						className={getNavItemClass('overview')}
						onClick={() => setActiveTab('overview')}
					>
						<FiHome className='w-4 h-4 mr-2' /> Overview
					</button>

					{projectTypeNavItems.map((item) => (
						<button
							key={item.id}
							className={getNavItemClass(item.id)}
							onClick={() => setActiveTab(item.id)}
						>
							{item.icon} {item.label}
						</button>
					))}

					<button
						className={getNavItemClass('versions')}
						onClick={() => setActiveTab('versions')}
					>
						<FiClock className='w-4 h-4 mr-2' /> Versions
					</button>

					<button
						className={getNavItemClass('collaborators')}
						onClick={() => setActiveTab('collaborators')}
					>
						<FiUsers className='w-4 h-4 mr-2' /> Collaborators
					</button>

					{isOwner && (
						<button
							className={getNavItemClass('settings')}
							onClick={() => setActiveTab('settings')}
						>
							<FiSettings className='w-4 h-4 mr-2' /> Settings
						</button>
					)}
				</div>
			</div>

			{/* Versions list */}
			<div>
				<div className='flex items-center justify-between px-3 mb-2'>
					<h3 className='text-xs uppercase text-gray-500 font-medium'>
						Versions
					</h3>

					<button
						onClick={onCreateVersion}
						className='text-gray-400 hover:text-white'
						title='Create new version'
					>
						<FiPlus className='w-4 h-4' />
					</button>
				</div>

				<div className='space-y-1 max-h-60 overflow-y-auto pr-1'>
					{versions.length > 0 ? (
						versions.map((version) => (
							<button
								key={version.id}
								className={`flex items-center py-2 px-3 rounded-md transition-colors w-full text-left ${
									selectedVersion?.id === version.id
										? 'bg-ableton-dark-200 text-white'
										: 'text-gray-400 hover:bg-ableton-dark-200/50 hover:text-gray-300'
								}`}
								onClick={() => setSelectedVersion(version)}
							>
								<div className='truncate'>
									<div className='font-medium truncate'>{version.title}</div>
									<div className='text-xs text-gray-500 truncate'>
										{new Date(version.created_at).toLocaleDateString()}
									</div>
								</div>
							</button>
						))
					) : (
						<div className='text-sm text-gray-500 py-2 px-3'>
							No versions yet
						</div>
					)}
				</div>
			</div>

			{/* Collaborators list */}
			<div>
				<h3 className='text-xs uppercase text-gray-500 font-medium mb-2 px-3'>
					Collaborators
				</h3>

				<div className='space-y-1 max-h-60 overflow-y-auto pr-1'>
					{collaborators.length > 0 ? (
						collaborators.map((collaborator) => (
							<div
								key={collaborator.id}
								className='flex items-center py-2 px-3'
							>
								<div className='w-6 h-6 rounded-full bg-ableton-blue-500 flex items-center justify-center text-white font-medium text-xs mr-2 flex-shrink-0'>
									{collaborator.username?.charAt(0)?.toUpperCase() || 'U'}
								</div>

								<div className='truncate'>
									<div className='font-medium truncate'>
										{collaborator.name || collaborator.username}
									</div>
									<div className='text-xs text-gray-500'>
										{collaborator.role}
									</div>
								</div>
							</div>
						))
					) : (
						<div className='text-sm text-gray-500 py-2 px-3'>
							No collaborators yet
						</div>
					)}
				</div>
			</div>
		</div>
	);
};

export default ProjectSidebar;
