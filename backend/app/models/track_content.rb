class TrackContent < ApplicationRecord
  belongs_to :container
  belongs_to :user
  
  # Add this line:
  has_many :file_attachments, as: :attachable, dependent: :destroy
  
  validates :title, presence: true
  validates :user, presence: true
  validates :container, presence: true
end