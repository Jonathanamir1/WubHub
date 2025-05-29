class TrackContent < ApplicationRecord
  belongs_to :track_version
  
  # Add Active Storage attachment
  has_one_attached :file
  
  validates :content_type, presence: true

  has_one :privacy, as: :privatable, dependent: :destroy

end