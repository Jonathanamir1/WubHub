class User < ApplicationRecord
  has_many :workspaces, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :collaborated_projects, through: :roles, source: :project
  has_many :track_versions, dependent: :destroy
  has_many :comments, dependent: :destroy

  # Add Active Storage attachment
  has_one_attached :profile_image

  # Validations
  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Add has_secure_password for password handling
  has_secure_password

  def all_workspaces
    # Return owned workspaces and those the user is a member of through roles
    # In a real implementation, you would query through associations
    Workspace.where(id: self.workspaces.pluck(:id))
  end
  
  def all_projects
    # Return owned projects and those the user is a collaborator on
    Project.where(id: self.projects.pluck(:id) + self.collaborated_projects.pluck(:id))
  end
end