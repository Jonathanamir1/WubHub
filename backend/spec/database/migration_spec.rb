require 'rails_helper'

RSpec.describe "Database Migrations", type: :model do
  describe "schema consistency" do
    it "has all required indexes for performance" do
      # Check critical indexes exist
      indexes = ActiveRecord::Base.connection.indexes('users')
      email_index = indexes.find { |i| i.columns == ['email'] && i.unique }
      username_index = indexes.find { |i| i.columns == ['username'] && i.unique }
      
      expect(email_index).to be_present, "Missing unique index on users.email"
      expect(username_index).to be_present, "Missing unique index on users.username"
    end

    it "has foreign key constraints properly set up" do
      # Check that foreign keys exist and are properly configured
      foreign_keys = ActiveRecord::Base.connection.foreign_keys('projects')
      
      workspace_fk = foreign_keys.find { |fk| fk.column == 'workspace_id' }
      user_fk = foreign_keys.find { |fk| fk.column == 'user_id' }
      
      expect(workspace_fk).to be_present
      expect(user_fk).to be_present
    end

    it "has proper polymorphic indexes" do
      # Check polymorphic indexes for roles
      indexes = ActiveRecord::Base.connection.indexes('roles')
      polymorphic_index = indexes.find { |i| i.columns.include?('roleable_type') && i.columns.include?('roleable_id') }
      
      expect(polymorphic_index).to be_present, "Missing polymorphic index on roles"
    end
  end

  describe "data integrity" do
    it "properly handles cascade deletes" do
      user = create(:user)
      workspace = create(:workspace, user: user)
      project = create(:project, workspace: workspace, user: user)
      track_version = create(:track_version, project: project, user: user)
      track_content = create(:track_content, track_version: track_version)
      
      # Delete user should cascade properly
      user_id = user.id
      user.destroy
      
      expect(Workspace.where(user_id: user_id)).to be_empty
      expect(Project.where(user_id: user_id)).to be_empty
      expect(TrackVersion.where(user_id: user_id)).to be_empty
    end

    it "handles jsonb fields properly" do
      track_version = create(:track_version, metadata: { tempo: 120, key: 'C major' })
      
      # Test jsonb querying
      found = TrackVersion.where("metadata->>'tempo' = ?", '120').first
      expect(found).to eq(track_version)
      
      # Test jsonb updating
      track_version.update!(metadata: track_version.metadata.merge(genre: 'Electronic'))
      track_version.reload
      
      expect(track_version.metadata['tempo']).to eq(120)
      expect(track_version.metadata['genre']).to eq('Electronic')
    end
  end
end