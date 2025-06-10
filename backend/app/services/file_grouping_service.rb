# app/services/file_grouping_service.rb
class FileGroupingService
  def initialize(workspace)
    @workspace = workspace
  end
  
  def find_files_starting_with(project_name, files)
    normalized_project_name = normalize_name(project_name)
    
    files.select do |file|
      normalized_filename = normalize_name(file.title)
      normalized_filename.start_with?(normalized_project_name)
    end
  end
  
  def suggest_project_name_from_files(files)
    return "Untitled Project" if files.empty?
    
    # Take the first filename and extract base name
    first_filename = files.first.title
    base_name = extract_base_name(first_filename)
    format_project_name(base_name)
  end
  
  def create_project_from_files(files, project_name)
    # Create the main project container
    project_container = @workspace.containers.create!(
      name: project_name,
      container_type: "project",
      template_level: 1
    )
    
    # Group files by extension using FileOrganizationService
    organization_service = FileOrganizationService.new(@workspace)
    categorized_files = organization_service.categorize_by_extension(files)
    
    # Create sub-containers and move files
    categorized_files.each do |container_name, file_group|
      sub_container = project_container.children.create!(
        workspace: @workspace,
        name: container_name,
        container_type: "folder",
        template_level: 2
      )
      
      # Move files to the sub-container
      file_group.each do |file|
        file.update!(container: sub_container)
      end
    end
    
    project_container
  end
  
  private
  
  def normalize_name(name)
    name.downcase
        .gsub(/[-_\s]+/, "_")  # Convert separators to underscores
        .gsub(/[^\w]/, "")     # Remove non-word characters except underscores
  end
  
  def extract_base_name(filename)
    # Remove extension and common suffixes
    base = File.basename(filename, ".*")
    base.gsub(/_(?:lyrics|demo|v\d+|final|rough|master|idea|cover)$/i, "")
  end
  
  def format_project_name(base_name)
    base_name.split("_")
             .map(&:capitalize)
             .join(" ")
  end
end