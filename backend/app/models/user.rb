class User < ApplicationRecord
  # Associations
  has_many :workspaces, dependent: :destroy
  has_many :roles, dependent: :destroy
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

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
  
end