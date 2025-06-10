require 'rails_helper'

RSpec.describe RoleSerializer, type: :serializer do
  describe 'serialization' do
    it 'includes generic roleable information' do
      user = create(:user)
      workspace = create(:workspace)
      role = create(:role, user: user, roleable: workspace, name: 'collaborator')
      
      serializer = RoleSerializer.new(role)
      serialization = JSON.parse(serializer.to_json)
      expect(serialization['id']).to eq(role.id)
      expect(serialization['name']).to eq('collaborator')
      expect(serialization['user_id']).to eq(user.id)
      expect(serialization['username']).to eq(user.username)
      expect(serialization['roleable_type']).to eq('Workspace')
      expect(serialization['roleable_id']).to eq(workspace.id)
    end
  end
end