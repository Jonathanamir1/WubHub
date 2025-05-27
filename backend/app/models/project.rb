# backend/app/models/project.rb
class Project < ApplicationRecord
  belongs_to :workspace
  belongs_to :user
  has_many :track_versions, dependent: :destroy
  has_many :roles, as: :roleable, dependent: :destroy
  has_many :collaborators, through: :roles, source: :user
  has_many :folders, dependent: :destroy
  has_many :audio_files, dependent: :destroy

  validates :title, presence: true
  validates :visibility, presence: true, inclusion: { in: ['private', 'public'] }

end