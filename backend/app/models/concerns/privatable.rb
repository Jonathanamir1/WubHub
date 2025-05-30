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
      if self.user == user
        return true
      end
      result = handle_inherited_access(user)
      return result
    else
      # Privacy record exists - privacy rules override everything (including ownership)
      case privacy_record.level
      when 'private'
        result = handle_private_access(user)
        return result
      when 'public'
        return true
      when 'inherited'
        if self.user == user
          return true
        end
        result = handle_inherited_access(user)
        return result
      else
        result = handle_private_access(user)
        return result
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
    has_role = user.roles.exists?(roleable: self)
    return true if has_role
    
    case self
    when Workspace
      false  # Only roles grant access, no inheritance
    when Project
      return false unless self.workspace
      result = self.workspace.accessible_by?(user)
      return result
    when TrackVersion
      return false unless self.project
      result = self.project.accessible_by?(user)
      return result
    when TrackContent
      return false unless self.track_version
      result = self.track_version.accessible_by?(user)
      return result
    else
      false
    end
  end
end