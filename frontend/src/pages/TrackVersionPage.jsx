import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import {
	Container,
	Title,
	Paper,
	Group,
	Button,
	Text,
	Divider,
	Avatar,
	Box,
	TextInput,
	Timeline,
	Loader,
	Alert,
} from '@mantine/core';
import { FiChevronLeft, FiPlus, FiSend, FiAlertCircle } from 'react-icons/fi';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/api';

const TrackVersionPage = () => {
	const { projectId, versionId } = useParams();
	const { currentUser } = useAuth();

	const [trackVersion, setTrackVersion] = useState(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [comment, setComment] = useState('');
	const [submittingComment, setSubmittingComment] = useState(false);

	useEffect(() => {
		const fetchTrackVersion = async () => {
			try {
				setLoading(true);

				// In a real implementation, this would be an actual API call
				// For now, we'll create dummy data
				const versionData = {
					id: parseInt(versionId),
					title: 'Mix v1',
					project_id: parseInt(projectId),
					user_id: 1,
					username: 'producer1',
					created_at: '2023-01-20T09:15:00Z',
					file_url: null, // In a real app, this would be a URL to the audio file
					waveform_data: null, // In a real app, this would be data for the waveform visualization
					comments: [
						{
							id: 1,
							content: 'The drums sound great in this version!',
							user_id: 2,
							username: 'vocalist',
							created_at: '2023-01-21T10:30:00Z',
							user_avatar: null,
						},
						{
							id: 2,
							content:
								'Thanks! I think the bass could use a bit more low end though.',
							user_id: 1,
							username: 'producer1',
							created_at: '2023-01-21T11:45:00Z',
							user_avatar: null,
						},
					],
					contents: [
						{
							id: 1,
							content_type: 'audio',
							file_url: null,
							created_at: '2023-01-20T09:15:00Z',
						},
						{
							id: 2,
							content_type: 'lyrics',
							text_content: 'These are sample lyrics for the song...',
							created_at: '2023-01-20T09:15:00Z',
						},
					],
				};

				setTrackVersion(versionData);
				setError(null);
			} catch (err) {
				console.error('Error fetching track version:', err);
				setError('Failed to load track version. Please try again later.');
			} finally {
				setLoading(false);
			}
		};

		fetchTrackVersion();
	}, [projectId, versionId]);

	const handleCommentSubmit = async (e) => {
		e.preventDefault();

		if (!comment.trim()) return;

		try {
			setSubmittingComment(true);

			// Mock comment submission
			console.log('Submitting comment:', comment);

			// Update state with new comment
			const newComment = {
				id: Date.now(), // Mock ID
				content: comment,
				user_id: currentUser.id,
				username: currentUser.username,
				created_at: new Date().toISOString(),
				user_avatar: currentUser.profile_image,
			};

			setTrackVersion((prev) => ({
				...prev,
				comments: [...prev.comments, newComment],
			}));

			setComment('');
		} catch (err) {
			console.error('Error submitting comment:', err);
			alert('Failed to submit comment. Please try again.');
		} finally {
			setSubmittingComment(false);
		}
	};

	if (loading) {
		return (
			<Container
				size='xl'
				style={{ display: 'flex', justifyContent: 'center', padding: '40px 0' }}
			>
				<Loader size='lg' />
			</Container>
		);
	}

	if (error) {
		return (
			<Container
				size='xl'
				py='xl'
			>
				<Alert
					icon={<FiAlertCircle size={16} />}
					title='Error'
					color='red'
				>
					{error}
				</Alert>
			</Container>
		);
	}

	if (!trackVersion) {
		return (
			<Container
				size='xl'
				py='xl'
			>
				<Alert
					icon={<FiAlertCircle size={16} />}
					title='Version Not Found'
					color='yellow'
				>
					The track version you are looking for does not exist or you do not
					have permission to view it.
				</Alert>
			</Container>
		);
	}

	const formatDate = (dateString) => {
		const date = new Date(dateString);
		return date.toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'long',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit',
		});
	};

	return (
		<Container size='xl'>
			<Button
				component={Link}
				to={`/projects/${projectId}`}
				variant='subtle'
				leftIcon={<FiChevronLeft size={16} />}
				mb='lg'
			>
				Back to Project
			</Button>

			<Paper
				p='md'
				withBorder
				mb='md'
			>
				<Group
					position='apart'
					mb='xs'
				>
					<div>
						<Title order={2}>{trackVersion.title}</Title>
						<Text
							size='sm'
							color='dimmed'
						>
							Uploaded by {trackVersion.username} on{' '}
							{formatDate(trackVersion.created_at)}
						</Text>
					</div>

					<Button leftIcon={<FiPlus size={16} />}>Add Content</Button>
				</Group>
			</Paper>

			{/* Audio Player would go here */}
			<Paper
				p='md'
				withBorder
				mb='xl'
			>
				<Text
					align='center'
					py='xl'
					color='dimmed'
				>
					Audio Player/Waveform would appear here
				</Text>
			</Paper>

			{/* Lyrics display would go here if applicable */}
			{trackVersion.contents.find((c) => c.content_type === 'lyrics') && (
				<Paper
					p='md'
					withBorder
					mb='xl'
				>
					<Title
						order={3}
						mb='md'
					>
						Lyrics
					</Title>
					<Text
						component='pre'
						style={{ whiteSpace: 'pre-wrap', fontFamily: 'inherit' }}
					>
						{
							trackVersion.contents.find((c) => c.content_type === 'lyrics')
								.text_content
						}
					</Text>
				</Paper>
			)}

			<Box>
				<Title
					order={3}
					mb='lg'
				>
					Comments
				</Title>

				<Paper
					p='md'
					withBorder
					mb='lg'
				>
					<form onSubmit={handleCommentSubmit}>
						<TextInput
							placeholder='Add a comment...'
							value={comment}
							onChange={(e) => setComment(e.currentTarget.value)}
							rightSection={
								<Button
									type='submit'
									compact
									variant='filled'
									loading={submittingComment}
									disabled={!comment.trim()}
									leftIcon={<FiSend size={16} />}
								>
									Post
								</Button>
							}
							rightSectionWidth={85}
						/>
					</form>
				</Paper>

				{trackVersion.comments && trackVersion.comments.length > 0 ? (
					<Timeline
						active={-1}
						bulletSize={24}
						lineWidth={2}
					>
						{trackVersion.comments.map((comment) => (
							<Timeline.Item
								key={comment.id}
								bullet={
									<Avatar
										size={24}
										radius='xl'
										src={comment.user_avatar}
									/>
								}
								title={
									<Group spacing='xs'>
										<Text
											weight={500}
											size='sm'
										>
											{comment.username}
										</Text>
										<Text
											size='xs'
											color='dimmed'
										>
											{formatDate(comment.created_at)}
										</Text>
									</Group>
								}
							>
								<Text size='sm'>{comment.content}</Text>
							</Timeline.Item>
						))}
					</Timeline>
				) : (
					<Text
						align='center'
						color='dimmed'
					>
						No comments yet. Be the first to comment!
					</Text>
				)}
			</Box>
		</Container>
	);
};

export default TrackVersionPage;
