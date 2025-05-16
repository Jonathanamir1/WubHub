# backend/db/migrate/20250516000001_move_type_from_workspace_to_project.rb
class MoveTypeFromWorkspaceToProject < ActiveRecord::Migration[7.1]
  def change
    # Add project_type to projects if it doesn't exist
    unless column_exists?(:projects, :project_type)
      add_column :projects, :project_type, :string, default: 'production'
    end
    
    # Update existing projects with a default type if workspace_type exists
    if column_exists?(:workspaces, :workspace_type)
      reversible do |dir|
        dir.up do
          execute <<-SQL
            UPDATE projects
            SET project_type = (
              SELECT workspace_type 
              FROM workspaces 
              WHERE workspaces.id = projects.workspace_id
            )
            WHERE EXISTS (
              SELECT 1 
              FROM workspaces 
              WHERE workspaces.id = projects.workspace_id 
              AND workspaces.workspace_type IS NOT NULL
            )
          SQL
        end
      end
      
      # Remove workspace_type from workspaces
      remove_column :workspaces, :workspace_type
    end
  end
end