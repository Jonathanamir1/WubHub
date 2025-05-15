import React from 'react';
import { Text, Container, Group, Anchor } from '@mantine/core';

const Footer = () => {
	return (
		<MantineFooter
			height={60}
			p='md'
		>
			{' '}
			// Use the renamed component
			<Container size='xl'>
				<Group
					position='apart'
					spacing='xl'
				>
					<Text
						size='sm'
						color='dimmed'
					>
						&copy; {new Date().getFullYear()} WubHub - Version Control for
						Musicians
					</Text>
					<Group
						spacing='xs'
						position='right'
						noWrap
					>
						<Anchor
							size='sm'
							color='dimmed'
							href='#'
						>
							Terms of Service
						</Anchor>
						<Anchor
							size='sm'
							color='dimmed'
							href='#'
						>
							Privacy Policy
						</Anchor>
						<Anchor
							size='sm'
							color='dimmed'
							href='#'
						>
							Contact
						</Anchor>
					</Group>
				</Group>
			</Container>
		</MantineFooter>
	);
};

export default Footer;
