module Privatable
  extend ActiveSupport::Concern

  included do
    has_one :privacy, as: :privatable, dependent: :destroy
  end

  def accessible_by?(user)
    return false unless user
    return true if self.user == user  # Owner always has access
    
    privacy_record = self.privacy
    
    if privacy_record.nil?
      # No privacy record = inherited behavior
      handle_inherited_access(user)
    else
      case privacy_record.level
      when 'private'
        handle_private_access(user)  # Change this line
      when 'public'
        true   # Anyone can access
      when 'inherited'
        handle_inherited_access(user)
      end
    end
  end

  private

  def handle_private_access(user)
    case self
    when Workspace
      user.has_access_to?(self)  # Check workspace roles
    else
      false  # Only owner for all other models
    end
  end

  def handle_inherited_access(user)
    case self
    when Workspace
      user.has_access_to?(self)
    when Project
      user.has_access_to?(self.workspace)
    when TrackVersion
      user.has_access_to?(self.project)
    when TrackContent
      user.has_access_to?(self.track_version)
    else
      false
    end
  end
end