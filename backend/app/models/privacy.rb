class Privacy < ApplicationRecord
  include PrivacyTypes

  belongs_to :user
  belongs_to :privatable, polymorphic: true
  
  validates :level, presence: true, inclusion: { in: ['inherited', 'private', 'public'] }
  validates :user_id, uniqueness: { scope: [:privatable_type, :privatable_id] }
  validates :privatable_type, inclusion: { in: ALLOWED_TYPES }
  validates :level, exclusion: { 
    in: ['private'], 
    message: "Workspaces cannot be private - remove collaborators instead" 
  }, if: -> { privatable_type == 'Workspace' }


  def private?
    level == 'private'
  end

  def public?
    level == 'public'
  end
end
