class User < ApplicationRecord
  # Associations
  has_many :workspaces, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :privacies, dependent: :destroy
  has_many :upload_sessions, dependent: :destroy
  has_many :queue_items, dependent: :destroy
  has_many :assets, dependent: :destroy
  
  # Active Storage for profile images
  has_one_attached :profile_image

  # Authentication
  has_secure_password

  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }, 
            format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 255 }
  validates :name, presence: true, length: { maximum: 100 }
  
  # Callbacks
  before_save :normalize_email
  
  # Onboarding step constants - Legacy system
  ONBOARDING_STEPS = [
    'not_started',
    'workspace_creation',
    'completed'
  ].freeze
  
  # Enhanced onboarding constants for new system
  DETAILED_ONBOARDING_STEPS = [
    'welcome',
    'profile_setup', 
    'workspace_setup',
    'final_setup',
    'completed'
  ].freeze
  
  # Validate both old and new onboarding steps
  validates :onboarding_step, inclusion: { in: ONBOARDING_STEPS + DETAILED_ONBOARDING_STEPS }, allow_blank: true
  
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
  
  def all_workspaces
    Workspace.where(id: self.workspaces.pluck(:id))
    # For a real implementation with collaborators, you'd include workspaces from collaborations
  end
  
  def owned_workspaces
    Workspace.where(user_id: id)
  end
  
  def can_access_workspace?(workspace)
    return false unless workspace
    return true if workspace.user_id == id
    
    # Check if user has a role for this workspace
    roles.exists?(roleable_type: 'Workspace', roleable_id: workspace.id)
  end
  
  # Onboarding status methods
  def onboarding_completed?
    onboarding_completed_at.present? || onboarding_step == 'completed'
  end
  
  def needs_onboarding?
    !onboarding_completed?
  end
  
  # Enhanced current_onboarding_step that maps old steps to new steps
  def current_onboarding_step
    return 'completed' if onboarding_completed?
    
    # Map legacy steps to new steps for backward compatibility
    case onboarding_step
    when 'not_started', nil, ''
      'welcome'
    when 'workspace_creation'
      'workspace_setup'
    else
      onboarding_step || 'welcome'
    end
  end
  
  def can_complete_onboarding?
    # User can complete onboarding if they have at least one workspace
    workspaces.exists?
  end
  
  # Legacy onboarding methods (for backward compatibility)
  def start_onboarding!
    # Enhanced system starts with 'welcome' instead of 'workspace_creation'
    update!(onboarding_step: 'welcome')
  end
  
  def complete_onboarding!
    update!(
      onboarding_step: 'completed',
      onboarding_completed_at: Time.current
    )
  end

  def can_create_first_workspace?
    # User can create their first workspace if they're in workspace_creation step
    # or workspace_type_selection step (we removed this step but keeping for flexibility)
    onboarding_step.in?(['workspace_creation']) && !onboarding_completed?
  end

  # Also, let's add a helper to check if this would be their first workspace
  def creating_first_workspace?
    workspaces.count == 0
  end
  
  def reset_onboarding!
    update!(
      onboarding_step: 'welcome',  # Enhanced system starts with 'welcome'
      onboarding_completed_at: nil  # Clear completion timestamp when restarting
    )
  end
  
  # Enhanced onboarding methods that integrate with OnboardingService
  def onboarding_service
    @onboarding_service ||= OnboardingService.new(self)
  end

  def can_access_onboarding_step?(step)
    onboarding_service.can_access_step?(step)
  end

  def onboarding_progress_percentage
    onboarding_service.progress_percentage
  end
  
  # Class methods
  def self.search(query)
    return all if query.blank?
    
    where("name ILIKE ? OR email ILIKE ?", "%#{query}%", "%#{query}%")
  end
  
  # Instance methods
  def display_name
    name.present? ? name : email.split('@').first
  end
  
  def profile_image_url
    return nil unless profile_image.attached?
    
    # For test environment, just return a simple path since disk service needs URL options
    if Rails.env.test?
      Rails.application.routes.url_helpers.rails_blob_path(profile_image, only_path: true)
    else
      profile_image.url
    end
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end