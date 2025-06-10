class FileOrganizationService
  # Extended extension mapping for music production
  EXTENSION_MAPPING = {
    # Audio Files
    ".wav" => "Audio Files",
    ".aac" => "Audio Files",
    ".flac" => "Audio Files",
    ".mp3" => "Audio Files",
    ".m4a" => "Audio Files",      # Apple/iPhone voice memos
    ".aiff" => "Audio Files",     # Pro Tools/Mac common
    ".ogg" => "Audio Files",      # Open source audio
    
    # Text & Documents  
    ".txt" => "Text Files",
    ".docx" => "Text Files",
    ".pdf" => "Text Files",
    ".doc" => "Text Files",       # Legacy Word docs
    ".rtf" => "Text Files",       # Rich text format
    ".md" => "Text Files",        # Markdown files
    
    # Project Files (we'll expand this as we build other templates)
    ".logicx" => "Project Files", # Logic Pro
    ".band" => "Project Files",   # GarageBand
    ".als" => "Project Files",    # Ableton Live
    ".ptx" => "Project Files",    # Pro Tools
    ".ptf" => "Project Files",    # Pro Tools
    ".pts" => "Project Files",    # Pro Tools
    ".song" => "Project Files",   # Studio One
    ".project" => "Project Files",# Studio One
    ".cpr" => "Project Files",    # Cubase
    ".flp" => "Project Files",    # FL Studio
    
    # Images (for cover art, moodboards)
    ".jpg" => "Images",
    ".jpeg" => "Images", 
    ".png" => "Images",
    ".gif" => "Images"
  }.freeze
  
  def initialize(workspace)
    @workspace = workspace
  end
  
  def categorize_by_extension(files)
    files.group_by do |file|
      extension = File.extname(file.title.downcase)
      EXTENSION_MAPPING[extension] || "Other Files"
    end
  end
end