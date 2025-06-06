require 'rails_helper'

RSpec.describe ContainerSerializer, type: :serializer do
  describe 'serialization' do
    it 'includes container attributes and hierarchy information' do
      workspace = create(:workspace)
      parent_container = create(:container, workspace: workspace, name: "Parent", template_level: 1)
      child_container = create(:container, 
        workspace: workspace, 
        parent_container: parent_container,
        name: "Child",
        template_level: 2
      )
      
      serializer = ContainerSerializer.new(child_container)
      serialization = JSON.parse(serializer.to_json)
      
      expect(serialization['id']).to eq(child_container.id)
      expect(serialization['name']).to eq("Child")
      expect(serialization['container_type']).to be_present
      expect(serialization['template_level']).to eq(2)
      expect(serialization['workspace_id']).to eq(workspace.id)
      expect(serialization['parent_container_id']).to eq(parent_container.id)
    end
  end
end