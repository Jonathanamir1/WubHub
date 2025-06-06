require 'rails_helper'

RSpec.describe ContainerBuilder, type: :service do
  describe '.build_hierarchy' do
    it 'creates a simple container hierarchy' do
      workspace = create(:workspace)
      user = create(:user)
      
      hierarchy_spec = {
        name: "My Beat Pack",
        container_type: "beat_pack", 
        template_level: 1,
        children: [
          {
            name: "Dark Nights Beat",
            container_type: "beat",
            template_level: 2
          }
        ]
      }
      
      result = ContainerBuilder.build_hierarchy(workspace, user, hierarchy_spec)
      
      expect(result[:success]).to be true
      expect(result[:root_container].name).to eq("My Beat Pack") 
      expect(result[:root_container].children.count).to eq(1)
      expect(result[:root_container].children.first.name).to eq("Dark Nights Beat")
    end

    it 'handles validation errors gracefully' do
      workspace = create(:workspace)
      user = create(:user)
      
      invalid_spec = {
        name: "",  # Invalid - name required
        container_type: "beat_pack",
        template_level: 1
      }
      
      result = ContainerBuilder.build_hierarchy(workspace, user, invalid_spec)
      
      expect(result[:success]).to be false
      expect(result[:root_container]).to be nil
      expect(result[:message]).to include("Failed to create hierarchy")
    end

    it 'creates nested hierarchy with multiple levels' do
      workspace = create(:workspace)
      user = create(:user)
      
      hierarchy_spec = {
        name: "Album",
        container_type: "release",
        template_level: 1,
        children: [
          {
            name: "Song 1",
            container_type: "song", 
            template_level: 2,
            children: [
              {
                name: "Demo Version",
                container_type: "version",
                template_level: 3
              },
              {
                name: "Final Version", 
                container_type: "version",
                template_level: 3
              }
            ]
          }
        ]
      }
      
      result = ContainerBuilder.build_hierarchy(workspace, user, hierarchy_spec)
      
      expect(result[:success]).to be true
      expect(result[:root_container].name).to eq("Album")
      
      song = result[:root_container].children.first
      expect(song.name).to eq("Song 1") 
      expect(song.children.count).to eq(2)
      expect(song.children.pluck(:name)).to include("Demo Version", "Final Version")
    end
  end
end