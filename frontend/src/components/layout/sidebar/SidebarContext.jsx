// frontend/src/components/layout/sidebar/SidebarContext.jsx
import React, { createContext, useState, useContext, useEffect } from 'react';
import api from '../../../services/api';

// Create context
const SidebarContext = createContext(null);

// Custom hook to use the sidebar context
export const useSidebar = () => {
	const context = useContext(SidebarContext);
	if (!context) {
		throw new Error('useSidebar must be used within a SidebarProvider');
	}
	return context;
};

export const SidebarProvider = ({ children }) => {
	const [workspaces, setWorkspaces] = useState([]);
	const [userWorkspaceOrder, setUserWorkspaceOrder] = useState([]);
	const [favoriteWorkspaces, setFavoriteWorkspaces] = useState([]);
	const [privateWorkspaces, setPrivateWorkspaces] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
	const [collapsedSections, setCollapsedSections] = useState({
		favorites: false,
		workspaces: false,
		private: false,
	});

	// Fetch workspaces
	useEffect(() => {
		fetchWorkspaces();
		fetchWorkspacePreferences();
	}, []);

	const fetchWorkspaces = async () => {
		try {
			setLoading(true);
			const response = await api.getWorkspaces();
			setWorkspaces(response.data || []);
			setError(null);
		} catch (err) {
			console.error('Error fetching workspaces for sidebar:', err);
			setError('Failed to load workspaces');
			// Fallback to mock data if API call fails during development
			fallbackToMockData();
		} finally {
			setLoading(false);
		}
	};

	// Fetch user preferences from backend
	const fetchWorkspacePreferences = async () => {
		try {
			const response = await api.getWorkspacePreferences();
			const {
				workspace_order,
				favorite_workspaces,
				private_workspaces,
				collapsed_sections,
			} = response.data;

			if (workspace_order && workspace_order.length > 0) {
				setUserWorkspaceOrder(workspace_order);
			}

			if (favorite_workspaces) {
				setFavoriteWorkspaces(favorite_workspaces);
			}

			if (private_workspaces) {
				setPrivateWorkspaces(private_workspaces);
			}

			if (collapsed_sections) {
				setCollapsedSections(collapsed_sections);
			}
		} catch (err) {
			console.error('Error fetching workspace preferences:', err);
			// Fall back to localStorage if API fails
			fallbackToLocalStorage();
		}
	};

	// Fallback to localStorage if API fails
	const fallbackToLocalStorage = () => {
		const savedOrder = localStorage.getItem('workspaceOrder');
		if (savedOrder) {
			setUserWorkspaceOrder(JSON.parse(savedOrder));
		}

		const savedFavorites = localStorage.getItem('favoriteWorkspaces');
		if (savedFavorites) {
			setFavoriteWorkspaces(JSON.parse(savedFavorites));
		}

		const savedPrivate = localStorage.getItem('privateWorkspaces');
		if (savedPrivate) {
			setPrivateWorkspaces(JSON.parse(savedPrivate));
		}

		const savedCollapsed = localStorage.getItem('collapsedSections');
		if (savedCollapsed) {
			setCollapsedSections(JSON.parse(savedCollapsed));
		}
	};

	// Fallback to mock data for development
	const fallbackToMockData = () => {
		const mockWorkspaces = [
			{
				id: 1,
				name: 'Personal Projects',
				project_count: 3,
			},
			{
				id: 2,
				name: 'Client Work',
				project_count: 5,
			},
			{
				id: 3,
				name: 'Band Collaboration',
				project_count: 2,
			},
			{
				id: 4,
				name: 'Mix Archive',
				project_count: 8,
			},
		];

		setWorkspaces(mockWorkspaces);
		setUserWorkspaceOrder([1, 2, 3, 4]);
		setFavoriteWorkspaces([1]);
		setPrivateWorkspaces([3]);
	};

	// Toggle section collapse
	const toggleSectionCollapse = async (section) => {
		const newCollapsed = {
			...collapsedSections,
			[section]: !collapsedSections[section],
		};
		setCollapsedSections(newCollapsed);

		// Update via API
		try {
			await api.updateCollapsedSections(newCollapsed);
		} catch (err) {
			console.error('Error updating collapsed sections:', err);
			// Update in localStorage as fallback
			localStorage.setItem('collapsedSections', JSON.stringify(newCollapsed));
		}
	};

	// Move workspace in order
	const moveWorkspace = async (fromIndex, toIndex) => {
		// Get the actual workspace IDs based on the current display order
		const sortedWorkspaces = getSortedWorkspaces();
		const orderedIds = sortedWorkspaces.map((w) => w.id);

		const newOrder = [...orderedIds];
		const [movedItem] = newOrder.splice(fromIndex, 1);
		newOrder.splice(toIndex, 0, movedItem);

		setUserWorkspaceOrder(newOrder);

		// Update via API
		try {
			await api.updateWorkspaceOrder(newOrder);
		} catch (err) {
			console.error('Error updating workspace order:', err);
			// Update in localStorage as fallback
			localStorage.setItem('workspaceOrder', JSON.stringify(newOrder));
		}
	};

	// Toggle workspace favorite status
	const toggleFavoriteWorkspace = async (workspaceId) => {
		const newFavorites = favoriteWorkspaces.includes(workspaceId)
			? favoriteWorkspaces.filter((id) => id !== workspaceId)
			: [...favoriteWorkspaces, workspaceId];

		setFavoriteWorkspaces(newFavorites);

		// Update via API
		try {
			await api.updateFavoriteWorkspaces(newFavorites);
		} catch (err) {
			console.error('Error updating favorite workspaces:', err);
			// Update in localStorage as fallback
			localStorage.setItem('favoriteWorkspaces', JSON.stringify(newFavorites));
		}
	};

	// Toggle workspace private status
	const togglePrivateWorkspace = async (workspaceId) => {
		const newPrivate = privateWorkspaces.includes(workspaceId)
			? privateWorkspaces.filter((id) => id !== workspaceId)
			: [...privateWorkspaces, workspaceId];

		setPrivateWorkspaces(newPrivate);

		// Update via API
		try {
			await api.updatePrivateWorkspaces(newPrivate);
		} catch (err) {
			console.error('Error updating private workspaces:', err);
			// Update in localStorage as fallback
			localStorage.setItem('privateWorkspaces', JSON.stringify(newPrivate));
		}
	};

	// Handle workspace deletion
	const handleDeleteWorkspace = async (id) => {
		try {
			await api.deleteWorkspace(id);

			// Update state
			setWorkspaces(workspaces.filter((w) => w.id !== id));

			// Update order
			const newOrder = userWorkspaceOrder.filter((wsId) => wsId !== id);
			setUserWorkspaceOrder(newOrder);

			// Remove from favorites and private if present
			if (favoriteWorkspaces.includes(id)) {
				const newFavs = favoriteWorkspaces.filter((wsId) => wsId !== id);
				setFavoriteWorkspaces(newFavs);
			}

			if (privateWorkspaces.includes(id)) {
				const newPrivate = privateWorkspaces.filter((wsId) => wsId !== id);
				setPrivateWorkspaces(newPrivate);
			}

			return true;
		} catch (err) {
			console.error('Error deleting workspace:', err);
			return false;
		}
	};

	// Add a new workspace
	const addWorkspace = (workspace) => {
		setWorkspaces([...workspaces, workspace]);

		// Add to order
		const newOrder = [...userWorkspaceOrder, workspace.id];
		setUserWorkspaceOrder(newOrder);

		// Update via API
		try {
			api.updateWorkspaceOrder(newOrder);
		} catch (err) {
			console.error('Error updating workspace order:', err);
			// Update in localStorage as fallback
			localStorage.setItem('workspaceOrder', JSON.stringify(newOrder));
		}
	};

	// Update an existing workspace
	const updateWorkspace = (updatedWorkspace) => {
		setWorkspaces(
			workspaces.map((ws) =>
				ws.id === updatedWorkspace.id ? updatedWorkspace : ws
			)
		);
	};

	// Get workspaces sorted by user order
	const getSortedWorkspaces = () => {
		// Make a copy of workspaces to sort
		const workspacesCopy = [...workspaces];

		// Sort by user's preferred order
		return workspacesCopy.sort((a, b) => {
			const indexA = userWorkspaceOrder.indexOf(a.id);
			const indexB = userWorkspaceOrder.indexOf(b.id);

			// If workspace doesn't exist in order, put it at the end
			if (indexA === -1) return 1;
			if (indexB === -1) return -1;

			return indexA - indexB;
		});
	};

	// Get favorite workspaces
	const getFavoriteWorkspaces = () => {
		return workspaces.filter((ws) => favoriteWorkspaces.includes(ws.id));
	};

	// Get private workspaces
	const getPrivateWorkspaces = () => {
		return workspaces.filter((ws) => privateWorkspaces.includes(ws.id));
	};

	// Get regular workspaces (not private or favorites)
	const getRegularWorkspaces = () => {
		const sorted = getSortedWorkspaces();
		return sorted.filter(
			(ws) =>
				!favoriteWorkspaces.includes(ws.id) &&
				!privateWorkspaces.includes(ws.id)
		);
	};

	const value = {
		workspaces,
		loading,
		error,
		sidebarCollapsed,
		setSidebarCollapsed,
		privateWorkspaces,
		collapsedSections,
		toggleSectionCollapse,
		moveWorkspace,
		toggleFavoriteWorkspace,
		togglePrivateWorkspace,
		handleDeleteWorkspace,
		addWorkspace,
		updateWorkspace,
		getFavoriteWorkspaces,
		getPrivateWorkspaces,
		getRegularWorkspaces,
		getSortedWorkspaces,
		refreshWorkspaces: fetchWorkspaces,
	};

	return (
		<SidebarContext.Provider value={value}>{children}</SidebarContext.Provider>
	);
};
