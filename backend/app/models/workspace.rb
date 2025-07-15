# app/models/workspace.rb
class Workspace < ApplicationRecord
  include Privatable
  
  # Associations
  belongs_to :user
  has_one :privacy, as: :privatable, dependent: :destroy
  has_many :containers, dependent: :destroy
  has_many :assets, dependent: :destroy
  has_many :upload_sessions, dependent: :destroy
  has_many :queue_items, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :description, length: { maximum: 1000 }
  validates :workspace_type, presence: true, inclusion: { 
    in: ['project_based', 'client_based', 'library'],
    message: "%{value} is not a valid workspace type"
  }
  
  # Workspace type helper methods
  def project_based?
    workspace_type == 'project_based'
  end
  
  def client_based?
    workspace_type == 'client_based'
  end
  
  def library?
    workspace_type == 'library'
  end
  
  # Workspace type constants for reference
  WORKSPACE_TYPES = %w[project_based client_based library].freeze
  
  # Scope methods for filtering by type
  scope :project_based, -> { where(workspace_type: 'project_based') }
  scope :client_based, -> { where(workspace_type: 'client_based') }
  scope :library, -> { where(workspace_type: 'library') }
  
  # Display helpers
  def workspace_type_display
    case workspace_type
    when 'project_based'
      'Project-Based'
    when 'client_based'
      'Client-Based'
    when 'library'
      'Library'
    else
      workspace_type&.humanize
    end
  end
  
  def workspace_type_description
    case workspace_type
    when 'project_based'
      'Organized by your music projects, albums, and creative work'
    when 'client_based'
      'Organized by clients and their individual projects'
    when 'library'
      'Collection of samples, loops, references, and sound libraries'
    else
      'Custom workspace organization'
    end
  end
end