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
			// Since this is a mock implementation, we'll create dummy data
			const workspaceData = [
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

			setWorkspaces(workspaceData);
			setError(null);
		} catch (err) {
			console.error('Error fetching workspaces for sidebar:', err);
			setError('Failed to load workspaces');
		} finally {
			setLoading(false);
		}
	};

	// Fetch user preferences (mock implementation)
	const fetchWorkspacePreferences = async () => {
		try {
			// Mock preferences
			setUserWorkspaceOrder([1, 2, 3, 4]);
			setFavoriteWorkspaces([1]);
			setPrivateWorkspaces([3]);
		} catch (err) {
			console.error('Error fetching workspace preferences:', err);
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

	// Toggle section collapse
	const toggleSectionCollapse = async (section) => {
		const newCollapsed = {
			...collapsedSections,
			[section]: !collapsedSections[section],
		};
		setCollapsedSections(newCollapsed);

		// Update in localStorage as fallback
		localStorage.setItem('collapsedSections', JSON.stringify(newCollapsed));

		// In a real implementation, you would update via API
		// await api.updateCollapsedSections(newCollapsed);
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

		// Update in localStorage as fallback
		localStorage.setItem('workspaceOrder', JSON.stringify(newOrder));

		// In a real implementation, you would update via API
		// await api.updateWorkspaceOrder(newOrder);
	};

	// Toggle workspace favorite status
	const toggleFavoriteWorkspace = (workspaceId) => {
		const newFavorites = favoriteWorkspaces.includes(workspaceId)
			? favoriteWorkspaces.filter((id) => id !== workspaceId)
			: [...favoriteWorkspaces, workspaceId];

		setFavoriteWorkspaces(newFavorites);
		localStorage.setItem('favoriteWorkspaces', JSON.stringify(newFavorites));
	};

	// Toggle workspace private status
	const togglePrivateWorkspace = (workspaceId) => {
		const newPrivate = privateWorkspaces.includes(workspaceId)
			? privateWorkspaces.filter((id) => id !== workspaceId)
			: [...privateWorkspaces, workspaceId];

		setPrivateWorkspaces(newPrivate);
		localStorage.setItem('privateWorkspaces', JSON.stringify(newPrivate));
	};

	// Handle workspace deletion
	const handleDeleteWorkspace = async (id) => {
		try {
			// Mock API call
			// await api.deleteWorkspace(id);

			// Update state
			setWorkspaces(workspaces.filter((w) => w.id !== id));

			// Update order
			const newOrder = userWorkspaceOrder.filter((wsId) => wsId !== id);
			setUserWorkspaceOrder(newOrder);
			localStorage.setItem('workspaceOrder', JSON.stringify(newOrder));

			// Remove from favorites and private if present
			if (favoriteWorkspaces.includes(id)) {
				const newFavs = favoriteWorkspaces.filter((wsId) => wsId !== id);
				setFavoriteWorkspaces(newFavs);
				localStorage.setItem('favoriteWorkspaces', JSON.stringify(newFavs));
			}

			if (privateWorkspaces.includes(id)) {
				const newPrivate = privateWorkspaces.filter((wsId) => wsId !== id);
				setPrivateWorkspaces(newPrivate);
				localStorage.setItem('privateWorkspaces', JSON.stringify(newPrivate));
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
		localStorage.setItem('workspaceOrder', JSON.stringify(newOrder));
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
	};

	return (
		<SidebarContext.Provider value={value}>{children}</SidebarContext.Provider>
	);
};
