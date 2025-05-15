class ProjectSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :visibility, :created_at, :updated_at, :workspace_id, :workspace_name, :version_count

  def workspace_name
    object.workspace.name
  end

  def version_count
    object.track_versions.count
  end
end