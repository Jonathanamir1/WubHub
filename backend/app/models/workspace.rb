class Workspace < ApplicationRecord
  include Privatable
  
  belongs_to :user
  has_one :privacy, as: :privatable, dependent: :destroy
  has_many :containers, dependent: :destroy
  has_many :assets, dependent: :destroy
  has_many :upload_sessions, dependent: :destroy
  has_many :queue_items, dependent: :destroy

  validates :name, presence: true
  validates :description, length: { maximum: 1000 }
  validates :workspace_type, inclusion: { 
    in: ['songwriter', 'producer', 'mixing_engineer', 'mastering_engineer', 'artist', 'other'],
    message: "%{value} is not a valid workspace type"
  }
  
  # Ensure workspace_type defaults to 'other' if not set
  before_validation :set_default_workspace_type
  
  private
  
  def set_default_workspace_type
    self.workspace_type = 'other' if workspace_type.blank?
  end
end