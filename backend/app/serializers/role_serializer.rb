class RoleSerializer < ActiveModel::Serializer
  attributes :id, :name, :user_id, :created_at, :updated_at, :username, :project_id

  belongs_to :user

  def username
    object.user&.username
  end

  def project_id
    object.roleable_id if object.roleable_type == 'Project'
  end
end