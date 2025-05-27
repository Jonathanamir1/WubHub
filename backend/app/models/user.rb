class User < ApplicationRecord
  # Associations
  has_many :workspaces, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :roles, dependent: :destroy
  # has_many :collaborated_projects, through: :roles, source: :project
  has_many :track_versions, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :audio_files, dependent: :destroy
  
  # Active Storage
  has_one_attached :profile_image

  # Authentication - THIS IS CRITICAL
  has_secure_password

  # Validations
  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  
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

  # Add user preferences association
  has_many :user_preferences, dependent: :destroy
  
  # Add a method to get accessible workspaces (owned + shared)
# app/models/user.rb
  def accessible_workspaces
    # For now, just return owned workspaces
    # In the future, you could expand this to include workspaces shared with the user
    self.workspaces
  end
  
  # Include only workspaces that the user owns
  def owned_workspaces
    Workspace.where(user_id: id)
  end
  
  # Get all workspace preferences for the user
  def workspace_preferences
    UserPreference.get_workspace_preferences(self)
  end
  
  def display_name
    name.present? ? name : username
  end

  def has_access_to?(resource)
    self.roles.exists?(roleable: resource)

    case resource
      when Project
        self.roles.exists?(roleable: resource.workspace)
      when TrackVersion
        self.roles.exists?(roleable: resource.project) ||
        self.roles.exists?(roleable: resource.project.workspace)
      when TrackContent
        self.roles.exists?(roleable: resource.track_version) ||
        self.roles.exists?(roleable: resource.project) ||
        self.roles.exists?(roleable: resource.workspace)
      else
        false
    end
  end

  def collaborated_projects
    Role.where(user: self, roleable_type: 'Project').includes(:roleable).map(&:roleable)
  end

  # Find or create a user preference
  def find_or_create_preference(key, default_value = nil)
    pref = user_preferences.find_or_initialize_by(key: key)
    pref.value = default_value if pref.new_record? && default_value.present?
    pref.save if pref.new_record?
    pref
  end

  
end