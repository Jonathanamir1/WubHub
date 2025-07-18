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
  before_save :ensure_onboarding_data_format
  
  # Enhanced Onboarding Constants
  DETAILED_ONBOARDING_STEPS = [
    'welcome',
    'profile_setup', 
    'workspace_setup',
    'final_setup',
    'completed'
  ].freeze
  
  # Legacy onboarding step constants (for backward compatibility)
  ONBOARDING_STEPS = [
    'not_started',
    'workspace_creation',
    'completed'
  ].freeze
  
  validates :onboarding_step, inclusion: { in: DETAILED_ONBOARDING_STEPS + ONBOARDING_STEPS }, allow_blank: true
  
  # Workspace access methods (unchanged)
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
  
  # ========================================
  # ENHANCED ONBOARDING SYSTEM
  # ========================================
  
  # Onboarding Data Management
  def onboarding_data_hash
    return {} if onboarding_data.blank?
    
    begin
      JSON.parse(onboarding_data)
    rescue JSON::ParserError
      {}
    end
  end
  
  def update_onboarding_data!(new_data)
    merged_data = onboarding_data_hash.merge(new_data.stringify_keys)
    update!(onboarding_data: merged_data.to_json)
  end
  
  # Step Progression Logic
  def can_access_step?(step)
    return true if onboarding_completed?
    return false unless step.in?(DETAILED_ONBOARDING_STEPS)
    
    current_step_index = DETAILED_ONBOARDING_STEPS.index(current_onboarding_step) || 0
    target_step_index = DETAILED_ONBOARDING_STEPS.index(step) || 0
    
    # Can access current step and all previous steps
    target_step_index <= current_step_index
  end
  
  def next_onboarding_step(current_step = nil)
    current_step ||= self.current_onboarding_step
    current_index = DETAILED_ONBOARDING_STEPS.index(current_step)
    
    return nil if current_index.nil? || current_index >= DETAILED_ONBOARDING_STEPS.length - 1
    
    DETAILED_ONBOARDING_STEPS[current_index + 1]
  end
  
  def advance_onboarding_step!
    current_step = current_onboarding_step
    next_step = next_onboarding_step(current_step)
    
    return if next_step.nil? || onboarding_completed?
    
    # Record completion of current step
    completed_steps = onboarding_data_hash['completed_steps'] || []
    step_timestamps = onboarding_data_hash['step_timestamps'] || {}
    
    unless completed_steps.include?(current_step)
      completed_steps << current_step
      step_timestamps[current_step] = Time.current.iso8601
    end
    
    # Update onboarding data
    update_onboarding_data!({
      'completed_steps' => completed_steps,
      'step_timestamps' => step_timestamps
    })
    
    # Advance to next step
    if next_step == 'completed'
      complete_onboarding!
    else
      update!(onboarding_step: next_step)
    end
  end
  
  # Enhanced Status Methods
  def current_onboarding_step
    return 'completed' if onboarding_completed?
    
    # Map legacy steps to new steps
    case onboarding_step
    when 'not_started', nil, ''
      'welcome'
    when 'workspace_creation'
      'workspace_setup'
    else
      onboarding_step || 'welcome'
    end
  end
  
  def onboarding_progress_percentage(step = nil)
    step ||= current_onboarding_step
    step_index = DETAILED_ONBOARDING_STEPS.index(step)
    return 0 if step_index.nil?
    
    case step
    when 'welcome'
      0
    when 'profile_setup'
      25
    when 'workspace_setup'
      50
    when 'final_setup'
      75
    when 'completed'
      100
    else
      0
    end
  end
  
  def step_completed?(step)
    return true if onboarding_completed?
    completed_steps = onboarding_data_hash['completed_steps'] || []
    completed_steps.include?(step.to_s)
  end
  
  # Flow Control
  def must_complete_onboarding?
    !onboarding_completed?
  end
  
  def reset_to_step!(target_step)
    return unless target_step.in?(DETAILED_ONBOARDING_STEPS)
    
    # Clear completion data
    update_onboarding_data!({
      'completed_steps' => [],
      'step_timestamps' => {}
    })
    
    # Reset to target step
    update!(
      onboarding_step: target_step,
      onboarding_completed_at: nil
    )
  end
  
  # Step-Specific Requirements
  def can_complete_profile_setup?
    name.present? && email.present?
  end
  
  def can_complete_workspace_setup?
    workspaces.exists?
  end
  
  # ========================================
  # LEGACY ONBOARDING METHODS (Backward Compatibility)
  # ========================================
  
  def onboarding_completed?
    onboarding_completed_at.present? || onboarding_step == 'completed'
  end
  
  def needs_onboarding?
    !onboarding_completed?
  end
  
  def can_complete_onboarding?
    # User can complete onboarding if they have at least one workspace
    workspaces.exists?
  end
  
  def start_onboarding!
    # Legacy method - now maps to new system
    update!(onboarding_step: 'welcome')
  end
  
  def complete_onboarding!
    update!(
      onboarding_step: 'completed',
      onboarding_completed_at: Time.current
    )
  end

  def can_create_first_workspace?
    # User can create their first workspace if they're in workspace_setup step
    current_onboarding_step.in?(['workspace_setup', 'workspace_creation']) && !onboarding_completed?
  end

  def creating_first_workspace?
    workspaces.count == 0
  end
  
  def reset_onboarding!
    reset_to_step!('welcome')
  end
  
  # Class methods
  def self.search(query)
    return all if query.blank?
    
    where("name ILIKE ? OR email ILIKE ?", "%#{query}%", "%#{query}%")
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
  
  def ensure_onboarding_data_format
    self.onboarding_data = '{}' if onboarding_data.blank?
  end
end