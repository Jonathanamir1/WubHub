class User < ApplicationRecord
  # Associations
  has_many :workspaces, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :privacies, dependent: :destroy
  
  # Active Storage for profile images
  has_one_attached :profile_image

  # Authentication
  has_secure_password

  # Validations
  validates :username, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 255 }
  
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
    'workspace_creation',  # Current step: create initial workspace
    'completed'
    # Future steps could be: 'profile_setup', 'team_invitation', etc.
  ].freeze
  
  validates :onboarding_step, inclusion: { in: ONBOARDING_STEPS }
  
  # Onboarding status methods
  def onboarding_completed?
    onboarding_completed_at.present? || onboarding_step == 'completed'
  end
  
  def needs_onboarding?
    !onboarding_completed? && !onboarding_skipped?
  end
  
  def current_onboarding_step
    return 'completed' if onboarding_completed?
    return 'skipped' if onboarding_skipped?
    onboarding_step || 'not_started'
  end
  
  def start_onboarding!
    update!(onboarding_step: 'workspace_creation')
  end
  
  def complete_onboarding!(skipped: false)
    update!(
      onboarding_step: 'completed',
      onboarding_completed_at: Time.current,
      onboarding_skipped: skipped
    )
  end
  
  def skip_onboarding!
    complete_onboarding!(skipped: true)
  end
  
  def reset_onboarding!
    update!(
      onboarding_step: 'not_started',
      onboarding_completed_at: nil,
      onboarding_skipped: false
    )
  end
  
  # Instance methods
  def display_name
    username
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end