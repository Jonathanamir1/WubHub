require 'rails_helper'

RSpec.describe Container, type: :model do
  describe 'validations' do
    it 'requires workspace to be present' do
      container = Container.new(workspace: nil)
      expect(container).not_to be_valid
      expect(container.errors[:workspace]).to include("must exist")
    end

    it 'allows parent_container to be nil for root containers' do
      workspace = create(:workspace)
      container = Container.new(
        workspace: workspace,
        parent_container: nil,
        name: "Root Container",
        container_type: "Container",
        template_level: 1  
      )
      expect(container).to be_valid
    end

    it 'requires name to be present' do
      workspace = create(:workspace)
      container = Container.new(
        workspace: workspace,
        name: nil 
      )
      expect(container).not_to be_valid
      expect(container.errors[:name]).to include("can't be blank")
    end

    it 'requires container_type to be present' do
      workspace = create(:workspace)
      container = Container.new(
        workspace: workspace,
        name: "Test Container",
        container_type: nil,
        template_level: 1  
      )
      expect(container).not_to be_valid
      expect(container.errors[:container_type]).to include("can't be blank")
    end

    it 'allows parent_container to be nil for root containers' do
      workspace = create(:workspace)
      container = Container.new(
        workspace: workspace,
        parent_container: nil,
        name: "Root Container",
        container_type: "folder",  
        template_level: 1         
      )
      expect(container).to be_valid
    end

    it 'requires template_level to be present' do
      workspace = create(:workspace)
      container = Container.new(
        workspace: workspace,
        name: "Test Container",
        container_type: "folder",
        template_level: nil
      )
      expect(container).not_to be_valid
      expect(container.errors[:template_level]).to include("can't be blank")
    end

    it 'can have child containers' do
      workspace = create(:workspace)
      parent = Container.create!(
        workspace: workspace,
        name: "Parent Container", 
        container_type: "folder",
        template_level: 1
      )
      
      child = Container.create!(
        workspace: workspace,
        parent_container: parent,
        name: "Child Container",
        container_type: "folder", 
        template_level: 2
      )
      
      expect(parent.children).to include(child)
      expect(child.parent_container).to eq(parent)
    end

    it 'prevents containers from being their own parent' do
      workspace = create(:workspace)
      container = Container.create!(
        workspace: workspace,
        name: "Test Container",
        container_type: "folder",
        template_level: 1
      )
      
      container.parent_container = container
      expect(container).not_to be_valid
      expect(container.errors[:parent_container]).to include("cannot be self")
    end

    it 'validates template_level is a positive integer' do
      workspace = create(:workspace)
      
      container = Container.new(
        workspace: workspace,
        name: "Test Container",
        container_type: "folder", 
        template_level: 0  # ❌ Should this be invalid?
      )
      
      expect(container).not_to be_valid
      expect(container.errors[:template_level]).to include("must be greater than or equal to 1")
    end

    it 'includes Privatable concern' do
      workspace = create(:workspace)
      container = Container.create!(
        workspace: workspace,
        name: "Test Container",
        container_type: "folder",
        template_level: 1
      )
      
      expect(container).to respond_to(:accessible_by?)
      expect(container).to respond_to(:privacy)
    end

    it 'stores and retrieves metadata as JSON' do
      workspace = create(:workspace)
      metadata = { 
        "file_count" => 5,           # ← String keys
        "total_size" => "2.5GB",     # ← String keys  
        "tags" => ["beat", "trap", "dark"] 
      }
      
      container = Container.create!(
        workspace: workspace,
        name: "Beat Pack",
        container_type: "beat_pack",
        template_level: 1,
        metadata: metadata
      )
      
      container.reload
      expect(container.metadata).to eq(metadata)
      expect(container.metadata["file_count"]).to eq(5)
      expect(container.metadata["tags"]).to include("beat")
    end
  end
end