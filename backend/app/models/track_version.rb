class TrackVersion < ApplicationRecord
  belongs_to :project
  belongs_to :user
  has_many :track_contents, dependent: :destroy
  
  validates :title, presence: true
  
end