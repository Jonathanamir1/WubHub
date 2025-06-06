class RoleSerializer < ActiveModel::Serializer
  attributes :id, :name, :user_id, :roleable_type, :roleable_id, :username
  
  def username
    object.user&.username
  end

end