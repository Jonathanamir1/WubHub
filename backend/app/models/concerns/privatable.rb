module Privatable
  extend ActiveSupport::Concern

  included do
    has_one :privacy, as: :privatable, dependent: :destroy
  end

  def accessible_by?(user)
    return false unless user
    return false unless user.id
    
    privacy_record = self.privacy
    
    if privacy_record.nil?
      # No privacy record - use inherited access (which includes ownership check)
      return true if self.user == user  # Owner access when no privacy
      handle_inherited_access(user)
    else
      # Privacy record exists - privacy rules override everything (including ownership)
      case privacy_record.level
      when 'private'
        handle_private_access(user)  # Only privacy setter has access
      when 'public'
        true
      when 'inherited'
        return true if self.user == user  # Owner access for inherited
        handle_inherited_access(user)
      else
        handle_private_access(user)
      end
    end
  end

  private

  def handle_private_access(user)
    privacy_record = self.privacy
    return false unless privacy_record
    
    # Only the person who set it private has access
    privacy_record.user == user
  end

  def handle_inherited_access(user)
    # First check if user has a direct role on THIS resource
    return true if user.roles.exists?(roleable: self)
    
    case self
    when Workspace
      # For workspaces, "inherited" means restricted (no parent to inherit from)
      false  # Only roles grant access, no inheritance
    when Project
      return false unless self.workspace
      self.workspace.accessible_by?(user)
    when TrackVersion
      return false unless self.project
      self.project.accessible_by?(user)
    when TrackContent
      return false unless self.track_version
      self.track_version.accessible_by?(user)
    else
      false
    end
  end
end