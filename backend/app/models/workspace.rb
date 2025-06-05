class Workspace < ApplicationRecord
  include Privatable

  belongs_to :user
  has_many :projects, dependent: :destroy
  
  # Add direct relationships for flexible hierarchy
  has_many :track_versions, dependent: :destroy
  has_many :track_contents, dependent: :destroy
  
  has_one :privacy, as: :privatable, dependent: :destroy

  validates :name, presence: true
end