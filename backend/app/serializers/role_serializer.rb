class RoleSerializer < ActiveModel::Serializer
  attributes :id, :name, :user_id, :roleable_type, :roleable_id, :email
  
  def email
    object.user&.email
  end
end