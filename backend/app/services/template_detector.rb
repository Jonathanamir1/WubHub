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
    return 'other' unless workspace.metadata.present?
    
    template_type = workspace.metadata["template_type"]
    return 'other' unless template_type.present?
    
    if VALID_TEMPLATES.include?(template_type)
      template_type
    else
      'other'
    end
  end
  
  # Helper method for frontend/forms
  def self.available_templates
    VALID_TEMPLATES
  end
end