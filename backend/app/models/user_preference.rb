class UserPreference < ApplicationRecord
  belongs_to :user
  
  # Store preferences as JSON
  serialize :value, coder: JSON
  
  # Validations
  validates :key, presence: true, uniqueness: { scope: :user_id }
  
  # Define common preference keys as constants
  WORKSPACE_ORDER = 'workspace_order'
  FAVORITE_WORKSPACES = 'favorite_workspaces'
  PRIVATE_WORKSPACES = 'private_workspaces'
  COLLAPSED_SECTIONS = 'collapsed_sections'
  
  # Scopes
  scope :workspace_orders, -> { where(key: WORKSPACE_ORDER) }
  scope :favorite_workspaces, -> { where(key: FAVORITE_WORKSPACES) }
  scope :private_workspaces, -> { where(key: PRIVATE_WORKSPACES) }
  scope :collapsed_sections, -> { where(key: COLLAPSED_SECTIONS) }
  
  # Get all workspace preferences for a user
  def self.get_workspace_preferences(user)
    prefs = user.user_preferences
    {
      workspace_order: prefs.find_by(key: WORKSPACE_ORDER)&.value || [],
      favorite_workspaces: prefs.find_by(key: FAVORITE_WORKSPACES)&.value || [],
      private_workspaces: prefs.find_by(key: PRIVATE_WORKSPACES)&.value || [],
      collapsed_sections: prefs.find_by(key: COLLAPSED_SECTIONS)&.value || {
        favorites: false,
        workspaces: false,
        private: false
      }
    }
  end
end