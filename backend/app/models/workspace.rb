class Workspace < ApplicationRecord
  include Privatable
  
  belongs_to :user
  has_one :privacy, as: :privatable, dependent: :destroy
  has_many :containers, dependent: :destroy
  has_many :assets, dependent: :destroy
  has_many :upload_sessions, dependent: :destroy


  validates :name, presence: true
  validates :description, length: { maximum: 1000 }
end