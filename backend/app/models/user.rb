class User < ApplicationRecord
  # Associations
  has_many :workspaces, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :track_versions, dependent: :destroy
  has_many :privacies, dependent: :destroy

  before_save :normalize_email

  
  # Active Storage
  has_one_attached :profile_image

  # Authentication - THIS IS CRITICAL
  has_secure_password

  # Validations
  validates :username, presence: true, uniqueness: true, length: { maximum: 50 } 
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 255 }
  validates :name, length: { maximum: 100 }
  
  # Returns all workspaces the user has access to (owned + collaborated)
  def all_workspaces
    Workspace.where(id: self.workspaces.pluck(:id))
    # For a real implementation with collaborators, you'd include workspaces from collaborations
  end
  
  # Returns all projects the user has access to (owned + collaborated)
  def all_projects
    Project.where(id: self.projects.pluck(:id) + self.collaborated_projects.pluck(:id))
  end
  
  # Returns recent projects for the user
  def recent_projects(limit = 10)
    # Get all accessible projects and sort by updated_at
    projects = self.all_projects
      .includes(:workspace) # Include workspace to avoid N+1 queries
      .order(updated_at: :desc)
      .limit(limit)
    
    # You could also add more logic here, like filtering by last activity
    projects
  end
  
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
  
  # Include only workspaces that the user owns
  def owned_workspaces
    Workspace.where(user_id: id)
  end
  
  
  def display_name
    name.present? ? name : username
  end

  def has_access_to?(resource)
    # Check direct access first
    return true if self.roles.exists?(roleable: resource)

    # Check inherited access from parent resources with nil safety
    case resource
    when Workspace
      # For workspaces, only direct roles matter (no inheritance)
      false  # Already checked above
    when Project
      return false unless resource.workspace
      self.roles.exists?(roleable: resource.workspace)
    when TrackVersion
      return false unless resource.project
      
      # Check project role
      has_project_access = self.roles.exists?(roleable: resource.project)
      
      # Check workspace role (if project has workspace)
      has_workspace_access = if resource.project.workspace
                              self.roles.exists?(roleable: resource.project.workspace)
                            else
                              false
                            end
      
      has_project_access || has_workspace_access
    when TrackContent
      return false unless resource.track_version
      return false unless resource.track_version.project
      
      # Check track version role
      has_version_access = self.roles.exists?(roleable: resource.track_version)
      
      # Check project role
      has_project_access = self.roles.exists?(roleable: resource.track_version.project)
      
      # Check workspace role (if project has workspace)
      has_workspace_access = if resource.track_version.project.workspace
                              self.roles.exists?(roleable: resource.track_version.project.workspace)
                            else
                              false
                            end
      
      has_version_access || has_project_access || has_workspace_access
    else
      false
    end
  end

  def collaborated_projects
    Role.where(user: self, roleable_type: 'Project').includes(:roleable).map(&:roleable)
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
  
end