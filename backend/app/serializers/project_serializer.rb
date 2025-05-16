# backend/app/serializers/project_serializer.rb
class ProjectSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :visibility, :project_type, :created_at, :updated_at, :workspace_id, :user_id

  def workspace_name
    object.workspace.name if object.workspace.present?
  end

  def version_count
    object.track_versions.count
  end
end