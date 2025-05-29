# backend/app/serializers/project_serializer.rb
class ProjectSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :created_at, :updated_at, :workspace_id, :user_id

  def workspace_name
    object.workspace.name if object.workspace.present?
  end

  def version_count
    object.track_versions.count
  end
  
  # Removed project_type from attributes
end