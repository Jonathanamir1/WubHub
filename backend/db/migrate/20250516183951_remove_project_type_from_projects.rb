# backend/db/migrate/20250516180000_remove_project_type_from_projects.rb
class RemoveProjectTypeFromProjects < ActiveRecord::Migration[7.1]
  def change
    # Remove project_type from projects
    remove_column :projects, :project_type, :string
  end
end