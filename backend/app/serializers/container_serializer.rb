class ContainerSerializer < ActiveModel::Serializer
  attributes :id, :name, :path, :parent_container_id, :workspace_id, :created_at, :updated_at

  has_many :child_containers, serializer: ContainerSerializer
  has_many :assets, serializer: AssetSerializer

  def child_containers
    object.child_containers.includes(:child_containers, :assets)
  end
end