# app/models/container.rb
class Container < ApplicationRecord
  include Privatable
  
  # Associations
  belongs_to :workspace
  belongs_to :parent_container, class_name: 'Container', optional: true
  has_many :child_containers, class_name: 'Container', foreign_key: 'parent_container_id', dependent: :destroy
  has_many :assets, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { 
    scope: [:workspace_id, :parent_container_id],
    message: 'has already been taken'
  }
  
  validate :parent_must_be_in_same_workspace
  validate :prevent_circular_references
  
  # Callbacks
  before_save :update_path
  
  # Instance methods
  def full_path
    return "/#{name}" if parent_container.nil?
    "#{parent_container.full_path}/#{name}"
  end
  
  def descendants
    Container.where(id: descendant_ids)
  end
  
  def descendant_ids
    child_ids = child_containers.pluck(:id)
    return child_ids if child_ids.empty?
    
    child_ids + child_containers.map(&:descendant_ids).flatten
  end
  
  def ancestors
    return [] if parent_container.nil?
    [parent_container] + parent_container.ancestors
  end
  
  def root?
    parent_container.nil?
  end
  
  def leaf?
    child_containers.empty?
  end
  
  private
  
  def update_path
    self.path = full_path
  end
  
  def parent_must_be_in_same_workspace
    return unless parent_container.present?
    
    if parent_container.workspace_id != workspace_id
      errors.add(:parent_container, 'must be in the same workspace')
    end
  end
  
  def prevent_circular_references
    return unless parent_container.present?
    
    if parent_container.descendant_ids.include?(id) || parent_container.id == id
      errors.add(:parent_container, 'cannot be a descendant of itself')
    end
  end
end# app/models/container.rb
class Container < ApplicationRecord
  include Privatable
  
  # Associations
  belongs_to :workspace
  belongs_to :parent_container, class_name: 'Container', optional: true
  has_many :child_containers, class_name: 'Container', foreign_key: 'parent_container_id', dependent: :destroy
  has_many :assets, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { 
    scope: [:workspace_id, :parent_container_id],
    message: 'has already been taken'
  }
  
  validate :parent_must_be_in_same_workspace
  validate :prevent_circular_references
  
  # Callbacks
  before_save :update_path
  
  # Instance methods
  def full_path
    return "/#{name}" if parent_container.nil?
    "#{parent_container.full_path}/#{name}"
  end
  
  def descendants
    Container.where(id: descendant_ids)
  end
  
  def descendant_ids
    child_ids = child_containers.pluck(:id)
    return child_ids if child_ids.empty?
    
    child_ids + child_containers.map(&:descendant_ids).flatten
  end
  
  def ancestors
    return [] if parent_container.nil?
    [parent_container] + parent_container.ancestors
  end
  
  def root?
    parent_container.nil?
  end
  
  def leaf?
    child_containers.empty?
  end
  
  private
  
  def update_path
    self.path = full_path
  end
  
  def parent_must_be_in_same_workspace
    return unless parent_container.present?
    
    if parent_container.workspace_id != workspace_id
      errors.add(:parent_container, 'must be in the same workspace')
    end
  end
  
  def prevent_circular_references
    return unless parent_container.present?
    
    if parent_container.descendant_ids.include?(id) || parent_container.id == id
      errors.add(:parent_container, 'cannot be a descendant of itself')
    end
  end
end