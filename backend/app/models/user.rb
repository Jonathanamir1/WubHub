class User < ApplicationRecord
  # Associations
  has_many :workspaces, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :collaborated_projects, through: :roles, source: :project
  has_many :track_versions, dependent: :destroy
  has_many :comments, dependent: :destroy

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
end