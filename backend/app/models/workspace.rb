class Workspace < ApplicationRecord
  belongs_to :user
  has_many :projects, dependent: :destroy
  
  has_one :privacy, as: :privatable, dependent: :destroy

  validates :name, presence: true
  
end