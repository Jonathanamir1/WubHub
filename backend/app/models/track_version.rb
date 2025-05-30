class TrackVersion < ApplicationRecord
  include Privatable

  belongs_to :project
  belongs_to :user
  
  has_many :track_contents, dependent: :destroy
  
  has_one :privacy, as: :privatable, dependent: :destroy
  
  validates :title, presence: true
  
end