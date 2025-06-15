# app/services/template_detector.rb
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
    return 'other' unless workspace.template_type.present?
    
    if VALID_TEMPLATES.include?(workspace.template_type)
      workspace.template_type
    else
      'other'
    end
  end
  
  # Helper method for frontend/forms
  def self.available_templates
    VALID_TEMPLATES
  end
end