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
  
  # Onboarding step constants
  ONBOARDING_STEPS = [
    'not_started',
    'workspace_creation',
    'completed'
  ].freeze
  
  validates :onboarding_step, inclusion: { in: ONBOARDING_STEPS }, allow_blank: true
  
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
  
  def current_onboarding_step
    return 'completed' if onboarding_completed?
    onboarding_step || 'not_started'
  end
  
  def can_complete_onboarding?
    # User can complete onboarding if they have at least one workspace
    workspaces.exists?
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