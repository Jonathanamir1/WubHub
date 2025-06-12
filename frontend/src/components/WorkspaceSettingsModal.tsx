// src/components/WorkspaceSettingsModal.tsx
'use client';

import { useState } from 'react';
import { Workspace } from '@/lib/types';
import { deleteWorkspace } from '@/lib/api';

interface WorkspaceSettingsModalProps {
	isOpen: boolean;
	onClose: () => void;
	workspace: Workspace | null;
	onWorkspaceDeleted: (workspaceId: number) => void;
}

export default function WorkspaceSettingsModal({
	isOpen,
	onClose,
	workspace,
	onWorkspaceDeleted,
}: WorkspaceSettingsModalProps) {
	const [activeSection, setActiveSection] = useState('general');
	const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
	const [deleteConfirmText, setDeleteConfirmText] = useState('');
	const [isDeleting, setIsDeleting] = useState(false);

	if (!isOpen || !workspace) return null;

	const handleDeleteWorkspace = async () => {
		if (deleteConfirmText !== workspace.name || isDeleting) return;

		setIsDeleting(true);
		const token = localStorage.getItem('wubhub_token');
		if (!token) return;

		try {
			const result = await deleteWorkspace(token, workspace.id);
			if (result.success) {
				onWorkspaceDeleted(workspace.id);
				onClose();
			} else {
				console.error('Failed to delete workspace:', result.error);
				alert('Failed to delete workspace. Please try again.');
			}
		} catch (error) {
			console.error('Failed to delete workspace:', error);
			alert('Failed to delete workspace. Please try again.');
		} finally {
			setIsDeleting(false);
		}
	};

	const canDelete = deleteConfirmText === workspace.name && !isDeleting;

	return (
		<div className='fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50'>
			<div className='bg-dark-900 rounded-lg w-full max-w-4xl max-h-[90vh] flex overflow-hidden'>
				{/* Sidebar */}
				<div className='w-72 bg-dark-800 border-r border-dark-600 flex flex-col'>
					{/* Header */}
					<div className='p-6 border-b border-dark-600'>
						<div className='flex items-center gap-3'>
							<div className='w-8 h-8 bg-gradient-to-br from-accent-blue to-blue-600 rounded-lg flex items-center justify-center text-sm font-bold text-white'>
								{workspace.name.charAt(0).toUpperCase()}
							</div>
							<div className='flex-1 min-w-0'>
								<h2 className='text-lg font-semibold text-white truncate'>
									{workspace.name}
								</h2>
								<p className='text-sm text-dark-400'>Workspace settings</p>
							</div>
						</div>
					</div>

					{/* Navigation */}
					<div className='flex-1 p-4'>
						<div className='space-y-1'>
							<div className='text-xs font-semibold text-dark-500 uppercase tracking-wider px-3 py-2 mb-2'>
								Workspace
							</div>

							<button
								onClick={() => setActiveSection('general')}
								className={`w-full flex items-center gap-3 px-3 py-2 text-sm rounded-lg transition-colors text-left ${
									activeSection === 'general'
										? 'bg-dark-700 text-white'
										: 'text-dark-300 hover:text-white hover:bg-dark-700'
								}`}
							>
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
								General
							</button>

							<button
								onClick={() => setActiveSection('people')}
								className={`w-full flex items-center gap-3 px-3 py-2 text-sm rounded-lg transition-colors text-left ${
									activeSection === 'people'
										? 'bg-dark-700 text-white'
										: 'text-dark-300 hover:text-white hover:bg-dark-700'
								}`}
							>
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
								People
							</button>

							<button
								onClick={() => setActiveSection('security')}
								className={`w-full flex items-center gap-3 px-3 py-2 text-sm rounded-lg transition-colors text-left ${
									activeSection === 'security'
										? 'bg-dark-700 text-white'
										: 'text-dark-300 hover:text-white hover:bg-dark-700'
								}`}
							>
								<svg
									width='16'
									height='16'
									viewBox='0 0 24 24'
									fill='none'
									stroke='currentColor'
									strokeWidth='2'
								>
									<rect
										width='18'
										height='11'
										x='3'
										y='11'
										rx='2'
										ry='2'
									/>
									<path d='M7 11V7a5 5 0 0110 0v4' />
								</svg>
								Security
							</button>
						</div>
					</div>

					{/* Close Button */}
					<div className='p-4 border-t border-dark-600'>
						<button
							onClick={onClose}
							className='w-full flex items-center justify-center gap-2 px-4 py-2 text-sm text-dark-400 hover:text-white hover:bg-dark-700 rounded-lg transition-colors'
						>
							<svg
								width='16'
								height='16'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
							>
								<path d='M18 6L6 18M6 6l12 12' />
							</svg>
							Close
						</button>
					</div>
				</div>

				{/* Main Content */}
				<div className='flex-1 flex flex-col'>
					{/* Content Header */}
					<div className='p-6 border-b border-dark-600'>
						<h1 className='text-xl font-semibold text-white'>
							{activeSection === 'general' && 'General'}
							{activeSection === 'people' && 'People & Permissions'}
							{activeSection === 'security' && 'Security & Privacy'}
						</h1>
					</div>

					{/* Content Body */}
					<div className='flex-1 overflow-y-auto p-6'>
						{activeSection === 'general' && (
							<div className='space-y-8 max-w-2xl'>
								{/* Workspace Info */}
								<div>
									<h3 className='text-lg font-medium text-white mb-4'>
										Workspace Information
									</h3>
									<div className='space-y-4'>
										<div>
											<label className='block text-sm font-medium text-accent-blue mb-2'>
												Workspace Name
											</label>
											<input
												type='text'
												defaultValue={workspace.name}
												className='form-input'
												placeholder='Enter workspace name'
											/>
										</div>
										<div>
											<label className='block text-sm font-medium text-accent-blue mb-2'>
												Description
											</label>
											<textarea
												defaultValue={workspace.description || ''}
												className='form-input resize-none'
												rows={3}
												placeholder='Describe this workspace...'
											/>
										</div>
									</div>
								</div>

								{/* Template Info */}
								<div>
									<h3 className='text-lg font-medium text-white mb-4'>
										Template
									</h3>
									<div className='p-4 bg-dark-800 rounded-lg border border-dark-600'>
										<div className='flex items-center gap-3'>
											<div className='w-10 h-10 bg-gradient-to-br from-accent-blue to-blue-600 rounded-lg flex items-center justify-center text-sm font-bold text-white'>
												{workspace.name.charAt(0).toUpperCase()}
											</div>
											<div>
												<p className='text-sm font-medium text-white'>
													{workspace.metadata?.template_type || 'Custom'}{' '}
													Template
												</p>
												<p className='text-xs text-dark-400'>
													This workspace was created with the{' '}
													{workspace.metadata?.template_type || 'custom'}{' '}
													template
												</p>
											</div>
										</div>
									</div>
								</div>

								{/* Danger Zone */}
								<div className='border-t border-dark-600 pt-8'>
									<h3 className='text-lg font-medium text-red-400 mb-4'>
										Danger Zone
									</h3>
									<div className='p-4 border border-red-800 bg-red-900/10 rounded-lg'>
										<div className='flex items-start justify-between'>
											<div className='flex-1'>
												<h4 className='text-sm font-medium text-white mb-1'>
													Delete this workspace
												</h4>
												<p className='text-sm text-dark-400 mb-4'>
													Once you delete a workspace, there is no going back.
													This will permanently delete all content,
													collaborators, and settings.
												</p>
											</div>
										</div>

										{!showDeleteConfirm ? (
											<button
												onClick={() => setShowDeleteConfirm(true)}
												className='px-4 py-2 bg-red-600 hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors'
											>
												Delete workspace
											</button>
										) : (
											<div className='space-y-4'>
												<div>
													<p className='text-sm text-white mb-2'>
														Type{' '}
														<strong className='text-red-400'>
															{workspace.name}
														</strong>{' '}
														to confirm deletion:
													</p>
													<input
														type='text'
														value={deleteConfirmText}
														onChange={(e) =>
															setDeleteConfirmText(e.target.value)
														}
														className='form-input mb-4'
														placeholder={workspace.name}
													/>
												</div>
												<div className='flex gap-3'>
													<button
														onClick={() => {
															setShowDeleteConfirm(false);
															setDeleteConfirmText('');
														}}
														className='px-4 py-2 bg-dark-700 hover:bg-dark-600 text-white text-sm font-medium rounded-lg transition-colors'
													>
														Cancel
													</button>
													<button
														onClick={handleDeleteWorkspace}
														disabled={!canDelete}
														className='px-4 py-2 bg-red-600 hover:bg-red-700 disabled:bg-red-800 disabled:opacity-50 text-white text-sm font-medium rounded-lg transition-colors'
													>
														{isDeleting ? 'Deleting...' : 'Delete workspace'}
													</button>
												</div>
											</div>
										)}
									</div>
								</div>
							</div>
						)}

						{activeSection === 'people' && (
							<div className='max-w-2xl'>
								<div className='text-center py-12'>
									<svg
										width='48'
										height='48'
										viewBox='0 0 24 24'
										fill='none'
										stroke='currentColor'
										strokeWidth='1'
										className='mx-auto mb-4 text-dark-500'
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
									<h3 className='text-lg font-medium text-white mb-2'>
										People & Permissions
									</h3>
									<p className='text-dark-400'>
										Manage workspace members and their permissions. This feature
										is coming soon.
									</p>
								</div>
							</div>
						)}

						{activeSection === 'security' && (
							<div className='max-w-2xl'>
								<div className='text-center py-12'>
									<svg
										width='48'
										height='48'
										viewBox='0 0 24 24'
										fill='none'
										stroke='currentColor'
										strokeWidth='1'
										className='mx-auto mb-4 text-dark-500'
									>
										<rect
											width='18'
											height='11'
											x='3'
											y='11'
											rx='2'
											ry='2'
										/>
										<path d='M7 11V7a5 5 0 0110 0v4' />
									</svg>
									<h3 className='text-lg font-medium text-white mb-2'>
										Security & Privacy
									</h3>
									<p className='text-dark-400'>
										Configure workspace security settings and privacy options.
										This feature is coming soon.
									</p>
								</div>
							</div>
						)}
					</div>
				</div>
			</div>
		</div>
	);
}
