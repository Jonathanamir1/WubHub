# app/services/template_detector.rb
class TemplateDetector
  # Available workspace template types
  AVAILABLE_TEMPLATES = %w[project_based client_based library].freeze
  
  class << self
    # Detect the appropriate template for a workspace
    def detect_template(workspace)
      return 'library' unless workspace&.workspace_type.present?
      
      workspace_type = workspace.workspace_type.to_s.strip
      
      if AVAILABLE_TEMPLATES.include?(workspace_type)
        workspace_type
      else
        'library'  # Default fallback for invalid or unknown types
      end
    end
    
    # Get all available template types
    def available_templates
      AVAILABLE_TEMPLATES.dup
    end
    
    # Get template display information
    def template_info(template_type)
      case template_type.to_s
      when 'project_based'
        {
          name: 'Project-Based',
          description: 'Organized by your music projects, albums, and creative work',
          icon: '🎵',
          structure: [
            'Album Projects',
            'Beat Library', 
            'Song Demos',
            'Works in Progress'
          ]
        }
      when 'client_based'
        {
          name: 'Client-Based',
          description: 'Organized by clients and their individual projects',
          icon: '🏢',
          structure: [
            'Client Name/Project Name',
            'Active Projects',
            'Completed Work',
            'Client Assets'
          ]
        }
      when 'library'
        {
          name: 'Library Collection',
          description: 'Collection of samples, loops, references, and sound libraries',
          icon: '📚',
          structure: [
            'Sample Packs',
            'Loop Libraries',
            'References',
            'Sound Design'
          ]
        }
      else
        {
          name: 'Unknown',
          description: 'Unknown workspace type',
          icon: '❓',
          structure: []
        }
      end
    end
    
    # Check if a template type is valid
    def valid_template?(template_type)
      AVAILABLE_TEMPLATES.include?(template_type.to_s)
    end
  end
end