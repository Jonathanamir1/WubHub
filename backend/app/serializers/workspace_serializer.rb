# backend/app/serializers/workspace_serializer.rb
class WorkspaceSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :visibility, :created_at, :updated_at, :user_id, :project_count

  def project_count
    begin
      object.projects.count
    rescue => e
      Rails.logger.error("Error in WorkspaceSerializer#project_count: #{e.message}")
      0 # Return 0 if there's an error
    end
  end
end