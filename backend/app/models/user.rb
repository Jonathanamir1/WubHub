# app/models/user.rb
class User < ApplicationRecord
  # Associations
  has_many :workspaces, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :privacies, dependent: :destroy
  has_many :upload_sessions, dependent: :destroy
  
  # Active Storage for profile images
  has_one_attached :profile_image

  # Authentication
  has_secure_password

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 255 }
  validates :name, presence: true, length: { maximum: 100 }
  
  # Note: Names can be duplicates, only email must be unique
  
  # Callbacks
  before_save :normalize_email
  
  # Workspace access methods
  def accessible_workspaces
    # Get owned workspaces
    owned_workspace_ids = self.workspaces.pluck(:id)
    
    # Get workspaces where user has roles
    collaborated_workspace_ids = self.roles.where(roleable_type: 'Workspace').pluck(:roleable_id)
    
    # Combine both lists
    all_workspace_ids = (owned_workspace_ids + collaborated_workspace_ids).uniq
    
    # Return all accessible workspaces
    Workspace.where(id: all_workspace_ids)
  end
  
  # Onboarding step constants
  ONBOARDING_STEPS = [
    'not_started',
    'workspace_creation',
    'completed'
  ].freeze
  
  validates :onboarding_step, inclusion: { in: ONBOARDING_STEPS }
  
  # Onboarding status methods
  def onboarding_completed?
    onboarding_completed_at.present? || onboarding_step == 'completed'
  end
  
  def needs_onboarding?
    !onboarding_completed?
  end
  
  def current_onboarding_step
    return 'completed' if onboarding_completed?
    onboarding_step || 'not_started'
  end
  
  def start_onboarding!
    update!(onboarding_step: 'workspace_creation')
  end
  
  def complete_onboarding!
    update!(
      onboarding_step: 'completed',
      onboarding_completed_at: Time.current
    )
  end
  
  def reset_onboarding!
    update!(
      onboarding_step: 'not_started',
      onboarding_completed_at: nil
    )
  end
  
  # Instance methods
  def display_name
    name
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end