# app/serializers/container_serializer.rb
class ContainerSerializer < ActiveModel::Serializer
  attributes :id, :name, :container_type, :template_level, :workspace_id, :parent_container_id, :metadata, :created_at, :updated_at
end