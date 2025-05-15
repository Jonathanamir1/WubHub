import React from 'react';
import {
	BrowserRouter as Router,
	Routes,
	Route,
	Navigate,
} from 'react-router-dom';
import { MantineProvider } from '@mantine/core';
import { AuthProvider, useAuth } from './contexts/AuthContext';

// Layout components
import MainLayout from './components/layout/MainLayout';

// Pages
import HomePage from './pages/HomePage';
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import DashboardPage from './pages/DashboardPage';
import WorkspacePage from './pages/WorkspacePage';
import ProjectPage from './pages/ProjectPage';
import TrackVersionPage from './pages/TrackVersionPage';

// Protected route component
const ProtectedRoute = ({ children }) => {
	const { isAuthenticated, loading } = useAuth();

	if (loading) {
		return <div>Loading...</div>;
	}

	if (!isAuthenticated) {
		return <Navigate to='/login' />;
	}

	return children;
};

function App() {
	return (
		<MantineProvider
			withGlobalStyles
			withNormalizeCSS
		>
			<AuthProvider>
				<Router>
					<Routes>
						<Route
							path='/'
							element={<MainLayout />}
						>
							<Route
								index
								element={<HomePage />}
							/>
							<Route
								path='login'
								element={<LoginPage />}
							/>
							<Route
								path='register'
								element={<RegisterPage />}
							/>

							<Route
								path='dashboard'
								element={
									<ProtectedRoute>
										<DashboardPage />
									</ProtectedRoute>
								}
							/>

							<Route
								path='workspaces/:workspaceId'
								element={
									<ProtectedRoute>
										<WorkspacePage />
									</ProtectedRoute>
								}
							/>

							<Route
								path='workspaces/:workspaceId/projects/:projectId'
								element={
									<ProtectedRoute>
										<ProjectPage />
									</ProtectedRoute>
								}
							/>

							<Route
								path='projects/:projectId/versions/:versionId'
								element={
									<ProtectedRoute>
										<TrackVersionPage />
									</ProtectedRoute>
								}
							/>
						</Route>
					</Routes>
				</Router>
			</AuthProvider>
		</MantineProvider>
	);
}

export default App;
