class Container < ApplicationRecord
  include Privatable

  belongs_to :workspace
  belongs_to :parent_container, class_name: 'Container', optional: true
  
  has_many :children, class_name: 'Container', foreign_key: 'parent_container_id'
  has_many :track_contents, dependent: :destroy 
  
  validates :name, presence: true
  validates :container_type, presence: true
  validates :template_level, presence: true

  validate :cannot_be_own_parent
  validates :template_level, presence: true, numericality: { greater_than_or_equal_to: 1 }


  private
  def cannot_be_own_parent
    if id.present? && parent_container_id.present? && parent_container_id == id
      errors.add(:parent_container, "cannot be self")
    end
  end
end