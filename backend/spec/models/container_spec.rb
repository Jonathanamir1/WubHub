# spec/models/container_spec.rb
require 'rails_helper'

RSpec.describe Container, type: :model do
  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should belong_to(:parent_container).optional }
    it { should have_many(:child_containers).class_name('Container').with_foreign_key('parent_container_id') }
    it { should have_many(:assets).dependent(:destroy) }
  end

  describe 'validations' do
    let(:workspace) { create(:workspace) }
    
    it { should validate_presence_of(:name) }
    
    it 'validates unique name within same parent container' do
      parent = create(:container, workspace: workspace)
      create(:container, name: 'Beats', parent_container: parent, workspace: workspace)
      
      duplicate = build(:container, name: 'Beats', parent_container: parent, workspace: workspace)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end
    
    it 'allows same name in different parent containers' do
      parent1 = create(:container, workspace: workspace)
      parent2 = create(:container, workspace: workspace)
      
      container1 = create(:container, name: 'Vocals', parent_container: parent1, workspace: workspace)
      container2 = build(:container, name: 'Vocals', parent_container: parent2, workspace: workspace)
      
      expect(container2).to be_valid
    end
    
    it 'validates unique name at workspace root level' do
      create(:container, name: 'Projects', workspace: workspace, parent_container: nil)
      
      duplicate = build(:container, name: 'Projects', workspace: workspace, parent_container: nil)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end
  end

  describe 'path generation' do
    let(:workspace) { create(:workspace) }
    
    it 'generates correct path for root container' do
      container = create(:container, name: 'Projects', workspace: workspace)
      expect(container.full_path).to eq('/Projects')
    end
    
    it 'generates correct path for nested containers' do
      parent = create(:container, name: 'Projects', workspace: workspace)
      child = create(:container, name: 'Song1', parent_container: parent, workspace: workspace)
      grandchild = create(:container, name: 'Stems', parent_container: child, workspace: workspace)
      
      expect(child.full_path).to eq('/Projects/Song1')
      expect(grandchild.full_path).to eq('/Projects/Song1/Stems')
    end
  end

  describe 'tree operations' do
    let(:workspace) { create(:workspace) }
    
    it 'prevents circular references' do
      parent = create(:container, name: 'Parent', workspace: workspace)
      child = create(:container, name: 'Child', parent_container: parent, workspace: workspace)
      
      # Try to make parent a child of child (circular reference)
      parent.parent_container = child
      expect(parent).not_to be_valid
      expect(parent.errors[:parent_container]).to include('cannot be a descendant of itself')
    end
    
    it 'finds all descendants' do
      parent = create(:container, name: 'Projects', workspace: workspace)
      child1 = create(:container, name: 'Song1', parent_container: parent, workspace: workspace)
      child2 = create(:container, name: 'Song2', parent_container: parent, workspace: workspace)
      grandchild = create(:container, name: 'Stems', parent_container: child1, workspace: workspace)
      
      descendants = parent.descendants
      expect(descendants).to contain_exactly(child1, child2, grandchild)
    end
  end

  describe 'workspace scoping' do
    it 'only allows containers within same workspace hierarchy' do
      workspace1 = create(:workspace)
      workspace2 = create(:workspace)
      
      parent_ws1 = create(:container, workspace: workspace1)
      child_ws2 = build(:container, parent_container: parent_ws1, workspace: workspace2)
      
      expect(child_ws2).not_to be_valid
      expect(child_ws2.errors[:parent_container]).to include('must be in the same workspace')
    end
  end

  describe 'file operations' do
    let(:workspace) { create(:workspace) }
    let(:container) { create(:container, workspace: workspace) }
    
    it 'deletes all files when container is deleted' do
      user = create(:user)
      # Create assets in the same workspace as the container
      asset1 = create(:asset, container: container, workspace: workspace, user: user)
      asset2 = create(:asset, container: container, workspace: workspace, user: user)
      
      expect { container.destroy }.to change(Asset, :count).by(-2)
    end
  end
end