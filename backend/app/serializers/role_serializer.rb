# backend/app/serializers/role_serializer.rb
class RoleSerializer < ActiveModel::Serializer
  attributes :id, :name, :user_id, :project_id, :created_at, :updated_at, :username

  belongs_to :user
  belongs_to :project

  def username
    object.user&.username
  end
end