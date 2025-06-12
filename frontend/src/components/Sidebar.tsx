// src/components/Sidebar.tsx
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Workspace } from '@/lib/types';
import { fetchWorkspaces, deleteWorkspace } from '@/lib/api';
import OnboardingModal from '@/components/OnboardingModal';

export default function Sidebar() {
	const router = useRouter();
	const [workspaces, setWorkspaces] = useState<Workspace[]>([]);
	const [isLoading, setIsLoading] = useState(true);
	const [showTemplateModal, setShowTemplateModal] = useState(false);
	const [showDeleteModal, setShowDeleteModal] = useState(false);
	const [workspaceToDelete, setWorkspaceToDelete] = useState<Workspace | null>(
		null
	);
	const [isDeleting, setIsDeleting] = useState(false);

	useEffect(() => {
		const token = localStorage.getItem('wubhub_token');
		if (token) {
			fetchUserWorkspaces(token);
		}
	}, []);

	const fetchUserWorkspaces = async (token: string) => {
		try {
			const result = await fetchWorkspaces(token);
			if (result.success) {
				setWorkspaces(result.data);
			} else if (result.status === 401) {
				localStorage.removeItem('wubhub_token');
				localStorage.removeItem('wubhub_user');
				router.push('/login');
			} else {
				console.error('Failed to fetch workspaces:', result.error);
			}
		} catch (error) {
			console.error('Failed to fetch workspaces:', error);
		} finally {
			setIsLoading(false);
		}
	};

	const handleTemplateModalComplete = () => {
		setShowTemplateModal(false);
		// Refresh workspaces
		const token = localStorage.getItem('wubhub_token');
		if (token) {
			fetchUserWorkspaces(token);
		}
	};

	const handleWorkspaceCreated = (workspace: Workspace) => {
		setWorkspaces((prev) => [...prev, workspace]);
	};

	const handleDeleteWorkspace = async () => {
		if (!workspaceToDelete) return;
		setIsDeleting(true);

		const token = localStorage.getItem('wubhub_token');
		if (!token) return;

		try {
			const result = await deleteWorkspace(token, workspaceToDelete.id);
			if (result.success) {
				setWorkspaces((prev) =>
					prev.filter((w) => w.id !== workspaceToDelete.id)
				);
				setShowDeleteModal(false);
				setWorkspaceToDelete(null);
			} else if (result.status === 401) {
				localStorage.removeItem('wubhub_token');
				localStorage.removeItem('wubhub_user');
				router.push('/login');
			} else {
				console.error('Failed to delete workspace:', result.error);
			}
		} catch (error) {
			console.error('Failed to delete workspace:', error);
		} finally {
			setIsDeleting(false);
		}
	};

	const openDeleteModal = (workspace: Workspace) => {
		setWorkspaceToDelete(workspace);
		setShowDeleteModal(true);
	};

	if (isLoading) {
		return (
			<div className='w-64 bg-dark-900 border-r border-dark-600 flex items-center justify-center'>
				<div className='text-dark-400'>Loading...</div>
			</div>
		);
	}

	return (
		<>
			<div className='w-64 bg-dark-900 border-r border-dark-600 flex flex-col'>
				{/* Workspaces Section - Now starts at the top */}
				<div className='flex-1 p-4'>
					<div className='flex items-center justify-between mb-4'>
						<h2 className='text-sm font-medium text-dark-300 uppercase tracking-wide'>
							Workspaces
						</h2>
						<button
							onClick={() => setShowTemplateModal(true)}
							className='w-6 h-6 rounded bg-dark-700 hover:bg-dark-600 flex items-center justify-center text-accent-blue transition-colors'
							title='Add workspace'
						>
							<svg
								width='14'
								height='14'
								viewBox='0 0 24 24'
								fill='none'
								stroke='currentColor'
								strokeWidth='2'
							>
								<path d='M12 5v14m-7-7h14' />
							</svg>
						</button>
					</div>

					{/* Workspaces List */}
					<div className='space-y-1'>
						{workspaces.length === 0 ? (
							<div className='text-sm text-dark-400 py-4 text-center'>
								No workspaces yet
							</div>
						) : (
							workspaces.map((workspace) => (
								<div
									key={workspace.id}
									className='group relative'
								>
									<button className='w-full text-left px-3 py-2 rounded-md text-sm text-dark-300 hover:bg-dark-700 hover:text-white transition-colors'>
										<div className='font-medium pr-8'>{workspace.name}</div>
										{workspace.description && (
											<div className='text-xs text-dark-400 mt-1 truncate pr-8'>
												{workspace.description}
											</div>
										)}
									</button>

									{/* Delete button - appears on hover */}
									<button
										onClick={(e) => {
											e.stopPropagation();
											openDeleteModal(workspace);
										}}
										className='absolute right-2 top-2 opacity-0 group-hover:opacity-100 w-6 h-6 rounded bg-dark-600 hover:bg-red-600 flex items-center justify-center text-dark-400 hover:text-white transition-all'
										title='Delete workspace'
									>
										<svg
											width='12'
											height='12'
											viewBox='0 0 24 24'
											fill='none'
											stroke='currentColor'
											strokeWidth='2'
										>
											<path d='M3 6h18m-2 0v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2' />
										</svg>
									</button>
								</div>
							))
						)}
					</div>
				</div>
			</div>

			{/* Template Modal for Adding Workspaces */}
			<OnboardingModal
				isOpen={showTemplateModal}
				onComplete={handleTemplateModalComplete}
				onWorkspaceCreated={handleWorkspaceCreated}
				isFirstTime={false}
			/>

			{/* Delete Workspace Modal */}
			{showDeleteModal && workspaceToDelete && (
				<div className='fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50'>
					<div className='bg-dark-800 rounded-lg border border-dark-600 w-full max-w-md'>
						<div className='p-6'>
							<h2 className='text-lg font-semibold text-white mb-4'>
								Delete Workspace
							</h2>
							<p className='text-dark-300 mb-6'>
								Are you sure you want to delete{' '}
								<strong>"{workspaceToDelete.name}"</strong>? This action cannot
								be undone and will permanently delete all projects and content
								within this workspace.
							</p>
							<div className='flex gap-3'>
								<button
									type='button'
									onClick={() => {
										setShowDeleteModal(false);
										setWorkspaceToDelete(null);
									}}
									className='btn-secondary flex-1'
								>
									Cancel
								</button>
								<button
									type='button'
									onClick={handleDeleteWorkspace}
									disabled={isDeleting}
									className='flex-1 py-2 px-4 rounded-md font-medium text-white transition-colors disabled:opacity-50 bg-red-600 hover:bg-red-700'
								>
									{isDeleting ? 'Deleting...' : 'Delete Workspace'}
								</button>
							</div>
						</div>
					</div>
				</div>
			)}
		</>
	);
}
