class Workspace < ApplicationRecord
  belongs_to :user
  has_many :projects, dependent: :destroy
  
  validates :name, presence: true
  validates :visibility, presence: true, inclusion: { in: ['private', 'public'] }
end