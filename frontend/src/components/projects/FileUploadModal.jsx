// frontend/src/components/projects/FileUploadModal.jsx
import React, { useState, useRef } from 'react';
import { FiX, FiUpload, FiFile } from 'react-icons/fi';

const FileUploadModal = ({
	show,
	onClose,
	onUpload,
	uploadType,
	versionId,
}) => {
	const [file, setFile] = useState(null);
	const [title, setTitle] = useState('');
	const [description, setDescription] = useState('');
	const [dragging, setDragging] = useState(false);
	const fileInputRef = useRef(null);

	if (!show) return null;

	const getUploadTypeLabel = () => {
		switch (uploadType) {
			case 'document':
				return 'Document';
			case 'audio':
				return 'Audio File';
			case 'image':
				return 'Image';
			case 'project':
				return 'Project File';
			default:
				return 'File';
		}
	};

	const handleDragOver = (e) => {
		e.preventDefault();
		setDragging(true);
	};

	const handleDragLeave = () => {
		setDragging(false);
	};

	const handleDrop = (e) => {
		e.preventDefault();
		setDragging(false);

		if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
			setFile(e.dataTransfer.files[0]);
		}
	};

	const handleFileChange = (e) => {
		if (e.target.files && e.target.files.length > 0) {
			setFile(e.target.files[0]);
		}
	};

	const handleSubmit = (e) => {
		e.preventDefault();

		if (!file) return;

		const metadata = {
			title: title || file.name,
			description,
			versionId,
		};

		onUpload(file, metadata);
	};

	return (
		<div className='fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50'>
			<div className='bg-ableton-dark-300 rounded-md shadow-xl w-full max-w-md'>
				<div className='flex justify-between items-center p-4 border-b border-ableton-dark-200'>
					<h2 className='text-xl font-medium'>Upload {getUploadTypeLabel()}</h2>

					<button
						onClick={onClose}
						className='text-gray-400 hover:text-white transition-colors'
					>
						<FiX className='w-5 h-5' />
					</button>
				</div>

				<form
					onSubmit={handleSubmit}
					className='p-4'
				>
					<div
						className={`border-2 border-dashed rounded-md p-6 flex flex-col items-center justify-center mb-4 transition-colors ${
							dragging
								? 'border-ableton-blue-500 bg-ableton-blue-500/10'
								: file
								? 'border-green-500 bg-green-500/10'
								: 'border-ableton-dark-100 hover:border-ableton-dark-50'
						}`}
						onDragOver={handleDragOver}
						onDragLeave={handleDragLeave}
						onDrop={handleDrop}
						onClick={() => fileInputRef.current?.click()}
					>
						<input
							type='file'
							ref={fileInputRef}
							onChange={handleFileChange}
							className='hidden'
						/>

						{file ? (
							<>
								<FiFile className='w-10 h-10 text-green-500 mb-2' />
								<p className='font-medium text-center'>{file.name}</p>
								<p className='text-sm text-gray-400 mt-1'>
									{(file.size / 1024 / 1024).toFixed(2)} MB
								</p>
								<button
									type='button'
									className='mt-2 text-sm text-ableton-blue-400 hover:text-ableton-blue-300'
									onClick={(e) => {
										e.stopPropagation();
										setFile(null);
									}}
								>
									Choose a different file
								</button>
							</>
						) : (
							<>
								<FiUpload className='w-10 h-10 text-gray-400 mb-2' />
								<p className='font-medium'>
									Drag & drop a file or click to browse
								</p>
								<p className='text-sm text-gray-400 mt-1'>
									Accepted file types:{' '}
									{uploadType === 'document' && '.doc, .docx, .pdf, .txt'}
									{uploadType === 'audio' && '.mp3, .wav, .aiff, .m4a'}
									{uploadType === 'image' && '.jpg, .png, .gif'}
									{uploadType === 'project' && '.als, .logic, .flp, .ptx'}
								</p>
							</>
						)}
					</div>

					<div className='mb-4'>
						<label className='block text-sm text-gray-400 mb-1'>Title</label>
						<input
							type='text'
							value={title}
							onChange={(e) => setTitle(e.target.value)}
							placeholder={file ? file.name : 'Enter a title for your file'}
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all'
						/>
					</div>

					<div className='mb-4'>
						<label className='block text-sm text-gray-400 mb-1'>
							Description (optional)
						</label>
						<textarea
							value={description}
							onChange={(e) => setDescription(e.target.value)}
							placeholder='Add a description...'
							className='w-full bg-ableton-dark-200 border border-ableton-dark-100 rounded-md p-3 text-white focus:outline-none focus:ring-2 focus:ring-ableton-blue-500 placeholder-gray-600 transition-all min-h-[80px]'
						/>
					</div>

					<div className='flex space-x-3'>
						<button
							type='button'
							onClick={onClose}
							className='flex-1 py-3 bg-ableton-dark-200 hover:bg-ableton-dark-100 text-white rounded-md transition-colors'
						>
							Cancel
						</button>

						<button
							type='submit'
							disabled={!file}
							className={`flex-1 py-3 rounded-md transition-colors ${
								file
									? 'bg-ableton-blue-500 hover:bg-ableton-blue-600 text-white'
									: 'bg-ableton-dark-200 text-gray-500 cursor-not-allowed'
							}`}
						>
							Upload
						</button>
					</div>
				</form>
			</div>
		</div>
	);
};

export default FileUploadModal;
