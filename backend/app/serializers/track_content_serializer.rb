# app/serializers/track_content_serializer.rb
class TrackContentSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :content_type, :text_content, :metadata, :container_id, :user_id, :created_at, :updated_at
end