# app/models/chunk.rb
class Chunk < ApplicationRecord
  belongs_to :upload_session
  
  validates :chunk_number, presence: true, uniqueness: { scope: :upload_session_id }
  validates :size, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending uploading completed failed] }
  
  scope :completed, -> { where(status: 'completed') }
  scope :pending, -> { where(status: 'pending') }
  scope :failed, -> { where(status: 'failed') }
end