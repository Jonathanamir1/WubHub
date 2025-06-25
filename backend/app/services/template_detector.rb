class TemplateDetector
  # Define the template types for your MVP
  VALID_TEMPLATES = [
    'songwriter',
    'producer', 
    'mixing_engineer',
    'mastering_engineer',
    'artist',
    'other'  
  ].freeze

  def self.detect_template(workspace)
    return 'other' unless workspace.workspace_type.present?
    
    if VALID_TEMPLATES.include?(workspace.workspace_type)
      workspace.workspace_type
    else
      'other'
    end
  end
  
  # Helper method for frontend/forms
  def self.available_templates
    VALID_TEMPLATES
  end
end