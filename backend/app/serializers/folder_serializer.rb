# backend/app/serializers/folder_serializer.rb
class FolderSerializer < ActiveModel::Serializer
  attributes :id, :name, :path, :created_at, :updated_at, :metadata
  
  has_many :subfolders
  has_many :audio_files
  
  belongs_to :user
  belongs_to :project
  belongs_to :parent_folder, optional: true
end