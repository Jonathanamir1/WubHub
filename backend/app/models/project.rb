class Project < ApplicationRecord
  belongs_to :workspace
  belongs_to :user
  has_many :track_versions, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :collaborators, through: :roles, source: :user
  
  validates :title, presence: true
  validates :visibility, presence: true, inclusion: { in: ['private', 'public'] }
end