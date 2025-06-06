class ContainerBuilder
  def self.build_hierarchy(workspace, user, hierarchy_spec)
    begin
      root_container = create_container(workspace, user, hierarchy_spec, nil)
      
      if hierarchy_spec[:children].present?
        create_children(workspace, user, hierarchy_spec[:children], root_container)
      end
      
      {
        success: true,
        root_container: root_container,
        message: "Hierarchy created successfully"
      }
    rescue => e
      {
        success: false,
        root_container: nil,
        message: "Failed to create hierarchy: #{e.message}"
      }
    end
  end
  
  private
  
  def self.create_container(workspace, user, spec, parent_container)
    workspace.containers.create!(
      name: spec[:name],
      container_type: spec[:container_type],
      template_level: spec[:template_level],
      parent_container: parent_container,
      metadata: spec[:metadata] || {}
    )
  end
  
  def self.create_children(workspace, user, children_specs, parent_container)
    children_specs.each do |child_spec|
      child_container = create_container(workspace, user, child_spec, parent_container)
      
      if child_spec[:children].present?
        create_children(workspace, user, child_spec[:children], child_container)
      end
    end
  end
end