# backend/app/models/project.rb
class Project < ApplicationRecord
  include Privatable
  
  belongs_to :workspace
  belongs_to :user
  has_many :track_versions, dependent: :destroy
  has_many :roles, as: :roleable, dependent: :destroy
  has_many :collaborators, through: :roles, source: :user

  has_one :privacy, as: :privatable, dependent: :destroy


  validates :title, presence: true

end