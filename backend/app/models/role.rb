class Role < ApplicationRecord
  belongs_to :user
  belongs_to :roleable, polymorphic: true

  validates :name, presence: true, inclusion: { in: ['owner', 'collaborator', 'commenter', 'viewer'] }
  validates :user_id, uniqueness: { scope: [:roleable_type, :roleable_id] }

  
end