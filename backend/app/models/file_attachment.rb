class FileAttachment < ApplicationRecord
  belongs_to :attachable, polymorphic: true
  belongs_to :user

  has_one_attached :file
  validates :filename, presence: true
end