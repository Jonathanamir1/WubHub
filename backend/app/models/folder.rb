# backend/app/models/folder.rb
class Folder < ApplicationRecord
  belongs_to :project
  belongs_to :user
  belongs_to :parent_folder, class_name: 'Folder', optional: true
  has_many :subfolders, class_name: 'Folder', foreign_key: 'parent_folder_id', dependent: :destroy
  has_many :audio_files, dependent: :destroy
  
  validates :name, presence: true
  validates :path, uniqueness: { scope: :project_id }
  
  before_validation :set_path
  
  private
  
  def set_path
    if parent_folder.present?
      self.path = "#{parent_folder.path}/#{name}"
    else
      self.path = "/#{name}"
    end
  end
end