class Workspace < ApplicationRecord
  include Privatable

  belongs_to :user
  
  has_many :containers, dependent: :destroy 
  has_one :privacy, as: :privatable, dependent: :destroy

  validates :name, presence: true
  
  serialize :metadata, coder: JSON

end