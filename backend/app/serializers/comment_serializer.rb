class CommentSerializer < ActiveModel::Serializer
  attributes :id, :content, :created_at, :updated_at
  
  belongs_to :user
  belongs_to :track_version
end