import React from 'react';
import { Outlet } from 'react-router-dom';
import { AppShell, Container } from '@mantine/core';
import Header from './Header';
import Footer from './Footer';

const MainLayout = () => {
	return (
		<AppShell
			padding='md'
			header={<Header />}
			footer={<Footer />}
			styles={(theme) => ({
				main: {
					backgroundColor:
						theme.colorScheme === 'dark'
							? theme.colors.dark[8]
							: theme.colors.gray[0],
					minHeight: 'calc(100vh - 120px)',
				},
			})}
		>
			<Container size='xl'>
				<Outlet />
			</Container>
		</AppShell>
	);
};

export default MainLayout;
