require 'rails_helper'

RSpec.describe TrackContentSerializer, type: :serializer do
  describe 'serialization' do
    it 'includes track content attributes and associations' do
      workspace = create(:workspace)
      container = create(:container, workspace: workspace)
      user = create(:user)
      
      track_content = create(:track_content,
        container: container,
        user: user,
        title: "My Beat",
        content_type: "audio",
        description: "A cool beat"
      )
      
      serializer = TrackContentSerializer.new(track_content)
      serialization = JSON.parse(serializer.to_json)
      
      expect(serialization['id']).to eq(track_content.id)
      expect(serialization['title']).to eq("My Beat")
      expect(serialization['content_type']).to eq("audio")
      expect(serialization['description']).to eq("A cool beat")
      expect(serialization['container_id']).to eq(container.id)
      expect(serialization['user_id']).to eq(user.id)
    end
  end
end