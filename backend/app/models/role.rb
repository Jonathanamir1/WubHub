class Role < ApplicationRecord
  belongs_to :user

  belongs_to :roleable, polymorphic: true

validates :name, presence: true, inclusion: { in: ['owner', 'collaborator', 'commenter', 'viewer'] }
end
