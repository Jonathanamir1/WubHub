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
end