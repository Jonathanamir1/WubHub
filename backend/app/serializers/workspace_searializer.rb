class WorkspaceSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :workspace_type, :visibility, :created_at, :updated_at, :project_count

  def project_count
    # Add error handling to prevent 500 errors
    begin
      object.projects.count
    rescue => e
      Rails.logger.error("Error in WorkspaceSerializer#project_count: #{e.message}")
      0 # Return 0 if there's an error
    end
  end
end