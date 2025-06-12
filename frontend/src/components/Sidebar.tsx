// src/components/Sidebar.tsx
'use client';

import { useState, useEffect } from 'react';
import { Workspace } from '@/lib/types';

interface SidebarProps {
	currentWorkspace?: Workspace | null;
}

export default function Sidebar({ currentWorkspace }: SidebarProps) {
	const [expandedSections, setExpandedSections] = useState<
		Record<string, boolean>
	>({
		'quick-access': true,
		projects: true,
		resources: false,
	});

	const toggleSection = (sectionId: string) => {
		setExpandedSections((prev) => ({
			...prev,
			[sectionId]: !prev[sectionId],
		}));
	};

	if (!currentWorkspace) {
		return (
			<div className='w-64 bg-dark-900 border-r border-dark-600 flex items-center justify-center'>
				<div className='text-center text-dark-400 p-6'>
					<div className='text-4xl mb-4'>📁</div>
					<p className='text-sm'>Select a workspace to get started</p>
				</div>
			</div>
		);
	}

	return (
		<div className='w-64 bg-dark-900 border-r border-dark-600 flex flex-col'>
			{/* Workspace Header */}
			<div className='p-4 border-b border-dark-600'>
				<div className='flex items-center gap-3'>
					<span className='text-xl'>🎵</span>
					<div className='flex-1 min-w-0'>
						<h2 className='font-semibold text-white truncate'>
							{currentWorkspace.name}
						</h2>
						{currentWorkspace.description && (
							<p className='text-xs text-dark-400 truncate'>
								{currentWorkspace.description}
							</p>
						)}
					</div>
				</div>
			</div>

			{/* Navigation Sections */}
			<div className='flex-1 overflow-y-auto'>
				{/* Quick Access */}
				<div className='p-2'>
					<button
						onClick={() => toggleSection('quick-access')}
						className='w-full flex items-center gap-2 px-2 py-1 text-sm text-dark-400 hover:text-white rounded-md transition-colors'
					>
						<svg
							width='14'
							height='14'
							viewBox='0 0 24 24'
							fill='none'
							stroke='currentColor'
							strokeWidth='2'
							className={`transition-transform ${
								expandedSections['quick-access'] ? 'rotate-90' : ''
							}`}
						>
							<path d='M9 18l6-6-6-6' />
						</svg>
						<span className='font-medium'>Quick Access</span>
					</button>

					{expandedSections['quick-access'] && (
						<div className='ml-4 mt-1 space-y-1'>
							<SidebarItem
								icon='🏠'
								label='Home'
							/>
							<SidebarItem
								icon='📥'
								label='Inbox'
							/>
							<SidebarItem
								icon='⭐'
								label='Favorites'
							/>
							<SidebarItem
								icon='🔄'
								label='Recent'
							/>
							<SidebarItem
								icon='🗑️'
								label='Trash'
							/>
						</div>
					)}
				</div>

				{/* Projects */}
				<div className='p-2'>
					<div className='flex items-center justify-between'>
						<button
							onClick={() => toggleSection('projects')}
							className='flex items-center gap-2 px-2 py-1 text-sm text-dark-400 hover:text-white rounded-md transition-colors'
						>
							<svg
								width='14'
								height='14'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
								className={`transition-transform ${
									expandedSections['projects'] ? 'rotate-90' : ''
								}`}
							>
								<path d='M9 18l6-6-6-6' />
							</svg>
							<span className='font-medium'>Projects</span>
						</button>
						<button className='w-5 h-5 rounded bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-dark-400 hover:text-white transition-colors'>
							<svg
								width='12'
								height='12'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
							>
								<path d='M12 5v14m-7-7h14' />
							</svg>
						</button>
					</div>

					{expandedSections['projects'] && (
						<div className='ml-4 mt-1 space-y-1'>
							<SidebarItem
								icon='🎤'
								label='Vocals Session 1'
							/>
							<SidebarItem
								icon='🥁'
								label='Drum Tracks'
							/>
							<SidebarItem
								icon='🎸'
								label='Guitar Ideas'
							/>
							<SidebarItem
								icon='🎹'
								label='Piano Compositions'
							/>
							<SidebarItem
								icon='🎵'
								label='Song Sketches'
							/>
						</div>
					)}
				</div>

				{/* Resources */}
				<div className='p-2'>
					<div className='flex items-center justify-between'>
						<button
							onClick={() => toggleSection('resources')}
							className='flex items-center gap-2 px-2 py-1 text-sm text-dark-400 hover:text-white rounded-md transition-colors'
						>
							<svg
								width='14'
								height='14'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
								className={`transition-transform ${
									expandedSections['resources'] ? 'rotate-90' : ''
								}`}
							>
								<path d='M9 18l6-6-6-6' />
							</svg>
							<span className='font-medium'>Resources</span>
						</button>
						<button className='w-5 h-5 rounded bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-dark-400 hover:text-white transition-colors'>
							<svg
								width='12'
								height='12'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
							>
								<path d='M12 5v14m-7-7h14' />
							</svg>
						</button>
					</div>

					{expandedSections['resources'] && (
						<div className='ml-4 mt-1 space-y-1'>
							<SidebarItem
								icon='🎼'
								label='Sheet Music'
							/>
							<SidebarItem
								icon='🎛️'
								label='Sample Library'
							/>
							<SidebarItem
								icon='📚'
								label='References'
							/>
							<SidebarItem
								icon='🔗'
								label='Links'
							/>
						</div>
					)}
				</div>

				{/* Templates Section */}
				<div className='p-2'>
					<div className='flex items-center justify-between'>
						<span className='px-2 py-1 text-xs font-medium text-dark-500 uppercase tracking-wide'>
							Templates
						</span>
						<button className='w-5 h-5 rounded bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-dark-400 hover:text-white transition-colors'>
							<svg
								width='12'
								height='12'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
							>
								<path d='M12 5v14m-7-7h14' />
							</svg>
						</button>
					</div>
					<div className='ml-2 mt-1 space-y-1'>
						<SidebarItem
							icon='📝'
							label='Song Structure'
						/>
						<SidebarItem
							icon='🎤'
							label='Recording Session'
						/>
						<SidebarItem
							icon='🎚️'
							label='Mix Notes'
						/>
					</div>
				</div>
			</div>

			{/* Workspace Actions */}
			<div className='p-4 border-t border-dark-600'>
				<button className='w-full flex items-center gap-3 px-3 py-2 text-sm text-dark-400 hover:text-white hover:bg-dark-700 rounded-md transition-colors'>
					<svg
						width='16'
						height='16'
						viewBox='0 0 24 24'
						fill='none'
						stroke='currentColor'
						strokeWidth='2'
					>
						<circle
							cx='12'
							cy='12'
							r='3'
						/>
						<path d='M12 1v6m0 6v6' />
						<path d='m9 12-6.93-4M15 12l6.93 4' />
					</svg>
					Workspace Settings
				</button>
				<button className='w-full flex items-center gap-3 px-3 py-2 text-sm text-dark-400 hover:text-white hover:bg-dark-700 rounded-md transition-colors mt-1'>
					<svg
						width='16'
						height='16'
						viewBox='0 0 24 24'
						fill='none'
						stroke='currentColor'
						strokeWidth='2'
					>
						<path d='M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2' />
						<circle
							cx='9'
							cy='7'
							r='4'
						/>
						<path d='M22 21v-2a4 4 0 00-3-3.87' />
						<path d='M16 3.13a4 4 0 010 7.75' />
					</svg>
					Invite Members
				</button>
			</div>
		</div>
	);
}

// Helper component for sidebar items
function SidebarItem({
	icon,
	label,
	isActive = false,
}: {
	icon: string;
	label: string;
	isActive?: boolean;
}) {
	return (
		<button
			className={`w-full flex items-center gap-3 px-2 py-1.5 text-sm rounded-md transition-colors ${
				isActive
					? 'bg-accent-blue text-dark-900 font-medium'
					: 'text-dark-300 hover:text-white hover:bg-dark-700'
			}`}
		>
			<span className='text-base'>{icon}</span>
			<span className='truncate'>{label}</span>
		</button>
	);
}
