class Workspace < ApplicationRecord
  include Privatable
  
  belongs_to :user
  has_one :privacy, as: :privatable, dependent: :destroy
  
  validates :name, presence: true
  validates :description, length: { maximum: 1000 }
end