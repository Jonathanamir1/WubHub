# spec/models/queue_item_spec.rb
require 'rails_helper'

RSpec.describe QueueItem, type: :model do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  
  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should belong_to(:user) }
    it { should have_many(:upload_sessions).dependent(:destroy) }
  end
  
  describe 'validations' do
    subject { build(:queue_item, workspace: workspace, user: user) }
    
    it { should validate_presence_of(:batch_id) }
    it { should validate_presence_of(:draggable_name) }
    # Note: draggable_type and status presence is automatically validated by Rails enums with defaults
    
    it { should validate_numericality_of(:total_files).only_integer.is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:completed_files).only_integer.is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:failed_files).only_integer.is_greater_than_or_equal_to(0) }
    
    # Test enum validations manually since shoulda matchers don't work well with Rails enums
    it 'validates draggable_type enum values' do
      queue_item = build(:queue_item, workspace: workspace, user: user)
      
      expect(queue_item).to be_valid
      
      # Test valid enum values
      queue_item.draggable_type = :folder
      expect(queue_item).to be_valid
      
      queue_item.draggable_type = :file  
      expect(queue_item).to be_valid
      
      queue_item.draggable_type = :mixed
      expect(queue_item).to be_valid
      
      # Test invalid enum value
      expect { queue_item.draggable_type = :invalid }.to raise_error(ArgumentError)
    end
    
    it 'validates status enum values' do
      queue_item = build(:queue_item, workspace: workspace, user: user)
      
      expect(queue_item).to be_valid
      
      # Test valid enum values
      [:pending, :processing, :completed, :failed, :cancelled].each do |status|
        queue_item.status = status
        expect(queue_item).to be_valid
      end
      
      # Test invalid enum value
      expect { queue_item.status = :invalid }.to raise_error(ArgumentError)
    end
    
    it 'validates that completed_files does not exceed total_files' do
      queue_item = build(:queue_item, total_files: 5, completed_files: 6, workspace: workspace, user: user)
      expect(queue_item).not_to be_valid
      expect(queue_item.errors[:completed_files]).to include('cannot exceed total files')
    end
    
    it 'validates that failed_files does not exceed total_files' do
      queue_item = build(:queue_item, total_files: 5, failed_files: 6, workspace: workspace, user: user)
      expect(queue_item).not_to be_valid
      expect(queue_item.errors[:failed_files]).to include('cannot exceed total files')
    end
    
    it 'allows zero total files for empty folders' do
      queue_item = build(:queue_item, total_files: 0, completed_files: 0, failed_files: 0, workspace: workspace, user: user)
      expect(queue_item).to be_valid
    end
  end
  
  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, processing: 1, completed: 2, failed: 3, cancelled: 4) }
    it { should define_enum_for(:draggable_type).with_values(folder: 0, file: 1, mixed: 2) }
  end
  
  describe 'scopes' do
    before do
      create(:queue_item, status: :pending, workspace: workspace, user: user)
      create(:queue_item, status: :processing, workspace: workspace, user: user)
      create(:queue_item, status: :completed, workspace: workspace, user: user)
      create(:queue_item, status: :failed, workspace: workspace, user: user)
    end
    
    it 'has active scope for non-terminal statuses' do
      active_items = QueueItem.active
      expect(active_items.pluck(:status)).to contain_exactly('pending', 'processing')
    end
    
    it 'has completed scope' do
      completed_items = QueueItem.completed
      expect(completed_items.pluck(:status)).to all(eq('completed'))
    end
    
    it 'has failed scope' do
      failed_items = QueueItem.failed
      expect(failed_items.pluck(:status)).to all(eq('failed'))
    end
    
    it 'has for_workspace scope' do
      other_workspace = create(:workspace, user: user)
      other_item = create(:queue_item, workspace: other_workspace, user: user)
      
      workspace_items = QueueItem.for_workspace(workspace)
      expect(workspace_items.count).to eq(4)
      expect(workspace_items).not_to include(other_item)
    end
    
    it 'has for_batch scope' do
      batch_id = SecureRandom.uuid
      batch_items = create_list(:queue_item, 3, batch_id: batch_id, workspace: workspace, user: user)
      other_item = create(:queue_item, workspace: workspace, user: user)
      
      batch_queue_items = QueueItem.for_batch(batch_id)
      expect(batch_queue_items.count).to eq(3)
      expect(batch_queue_items).not_to include(other_item)
    end
  end
  
  describe 'instance methods' do
    let(:queue_item) { create(:queue_item, total_files: 10, completed_files: 3, failed_files: 1, workspace: workspace, user: user) }
    
    describe '#progress_percentage' do
      it 'calculates progress based on completed files' do
        expect(queue_item.progress_percentage).to eq(30.0)
      end
      
      it 'returns 0 when no files completed' do
        queue_item.update!(completed_files: 0)
        expect(queue_item.progress_percentage).to eq(0.0)
      end
      
      it 'returns 100 when all files completed' do
        queue_item.update!(completed_files: 10)
        expect(queue_item.progress_percentage).to eq(100.0)
      end
      
      it 'handles zero total files gracefully' do
        queue_item.update!(total_files: 0, completed_files: 0, failed_files: 0)
        expect(queue_item.progress_percentage).to eq(0.0)
      end
    end
    
    describe '#pending_files' do
      it 'calculates remaining files to process' do
        expect(queue_item.pending_files).to eq(6)  # 10 - 3 - 1
      end
    end
    
    describe '#is_complete?' do
      it 'returns true when all files are processed' do
        queue_item.update!(completed_files: 8, failed_files: 2)  # 8 + 2 = 10 total
        expect(queue_item.is_complete?).to be true
      end
      
      it 'returns false when files are still pending' do
        expect(queue_item.is_complete?).to be false
      end
    end
    
    describe '#has_failures?' do
      it 'returns true when there are failed files' do
        expect(queue_item.has_failures?).to be true
      end
      
      it 'returns false when no failed files' do
        queue_item.update!(failed_files: 0)
        expect(queue_item.has_failures?).to be false
      end
    end
    
    describe '#mark_file_completed!' do
      it 'increments completed files count' do
        expect { queue_item.mark_file_completed! }.to change { queue_item.completed_files }.by(1)
      end
      
      it 'updates status to completed when all files done' do
        queue_item.update!(completed_files: 9, failed_files: 0)  # 9 completed, 1 pending
        
        expect { queue_item.mark_file_completed! }.to change { queue_item.status }.to('completed')
      end
      
      it 'updates status to failed when some files failed but all processed' do
        queue_item.update!(completed_files: 8, failed_files: 1)  # 9 processed, 1 pending
        
        expect { queue_item.mark_file_completed! }.to change { queue_item.status }.to('failed')
      end
    end
    
    describe '#mark_file_failed!' do
      it 'increments failed files count' do
        expect { queue_item.mark_file_failed! }.to change { queue_item.failed_files }.by(1)
      end
      
      it 'updates status to failed when all files processed with failures' do
        queue_item.update!(completed_files: 8, failed_files: 1)  # 9 processed, 1 pending
        
        expect { queue_item.mark_file_failed! }.to change { queue_item.status }.to('failed')
      end
    end
  end
  
  describe 'lifecycle and status management' do
    let(:queue_item) { create(:queue_item, workspace: workspace, user: user) }
    
    it 'starts in pending status' do
      expect(queue_item.status).to eq('pending')
    end
    
    it 'can transition to processing' do
      queue_item.start_processing!
      expect(queue_item.status).to eq('processing')
    end
    
    it 'can be cancelled from any status' do
      queue_item.start_processing!
      queue_item.cancel!
      expect(queue_item.status).to eq('cancelled')
    end
  end
  
  describe 'metadata handling' do
    let(:queue_item) do
      create(:queue_item,
        workspace: workspace,
        user: user,
        metadata: {
          upload_source: 'drag_drop',
          client_info: { browser: 'Chrome', version: '91.0' },
          original_folder_structure: ['Drums', 'Vocals', 'Guitar']
        }
      )
    end
    
    it 'stores and retrieves upload metadata' do
      expect(queue_item.metadata['upload_source']).to eq('drag_drop')
      expect(queue_item.metadata['client_info']['browser']).to eq('Chrome')
      expect(queue_item.metadata['original_folder_structure']).to include('Drums', 'Vocals', 'Guitar')
    end
    
    it 'handles empty metadata gracefully' do
      empty_item = create(:queue_item, workspace: workspace, user: user, metadata: {})
      expect(empty_item.metadata).to eq({})
    end
  end
end