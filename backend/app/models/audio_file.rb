# backend/app/models/audio_file.rb
class AudioFile < ApplicationRecord
  belongs_to :folder
  belongs_to :project
  belongs_to :user
  
  has_one_attached :file
  
  validates :filename, presence: true, uniqueness: { scope: :folder_id }
  
  # Audio file types allowed
  ALLOWED_CONTENT_TYPES = [
    'audio/mpeg',         # .mp3
    'audio/mp4',          # .m4a
    'audio/wav',          # .wav
    'audio/x-wav',        # alternative MIME type for .wav
    'audio/aiff',         # .aiff
    'audio/x-aiff',       # alternative MIME type for .aiff
    'audio/flac',         # .flac
    'audio/ogg',          # .ogg
    'audio/x-ms-wma'      # .wma
  ]
  
  def analyze_audio
    # Here we'd use an audio processing library to extract duration and generate waveform
    # This is a placeholder - in a real implementation, you'd integrate with something like ffmpeg
    # For now, we'll extract basic metadata from the attached file
    
    if file.attached?
      self.file_size = file.byte_size
      self.file_type = file.content_type
      
      # In a real implementation, you'd extract duration and generate waveform data here
      # self.duration = ...
      # self.waveform_data = ...
    end
  end
end