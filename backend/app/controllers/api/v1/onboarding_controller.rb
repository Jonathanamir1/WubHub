class Api::V1::OnboardingController < ApplicationController
  before_action :authenticate_user!

  # GET /api/v1/onboarding/status
  def status
    render json: {
      needs_onboarding: current_user.needs_onboarding?,
      current_step: current_user.current_onboarding_step,
      completed_at: current_user.onboarding_completed_at
    }
  end

  # POST /api/v1/onboarding/start
  def start
    current_user.start_onboarding!
    render json: { 
      message: 'Onboarding started',
      current_step: current_user.current_onboarding_step
    }
  end

  # POST /api/v1/onboarding/create_first_workspace
  def create_first_workspace
    # Validate user can create workspace at this step
    unless current_user.can_create_first_workspace? || current_user.current_onboarding_step == 'workspace_creation'
      return render json: { 
        error: 'Cannot create workspace at this onboarding step. Please start onboarding first.' 
      }, status: :unprocessable_entity
    end

    # Validate workspace parameters
    workspace_params = params.require(:workspace).permit(:name, :description, :workspace_type)
    
    unless workspace_params[:workspace_type].in?(Workspace::WORKSPACE_TYPES)
      return render json: {
        error: "Invalid workspace type. Must be one of: #{Workspace::WORKSPACE_TYPES.join(', ')}"
      }, status: :unprocessable_entity
    end

    unless workspace_params[:name].present?
      return render json: {
        errors: ["Name can't be blank"]
      }, status: :unprocessable_entity
    end

    # Create workspace with transaction to ensure consistency
    workspace = nil
    containers_created = []

    begin
      ActiveRecord::Base.transaction do
        # Create the workspace
        workspace = current_user.workspaces.create!(workspace_params)
        
        # Generate template containers based on workspace type
        containers_created = WorkspaceTemplateService.new(workspace).create_template_structure!
        
        # Auto-complete onboarding since they successfully created their first workspace
        current_user.complete_onboarding!
      end

      # Return success response with workspace and container details
      render json: {
        message: 'First workspace created successfully',
        workspace: {
          id: workspace.id,
          name: workspace.name,
          description: workspace.description,
          workspace_type: workspace.workspace_type,
          created_at: workspace.created_at
        },
        containers_created: containers_created.map do |container|
          {
            id: container.id,
            name: container.name,
            path: container.path
          }
        end,
        current_step: current_user.current_onboarding_step,
        onboarding_completed: current_user.onboarding_completed?
      }, status: :created

    rescue ActiveRecord::RecordInvalid => e
      # Handle validation errors
      render json: {
        errors: e.record.errors.full_messages
      }, status: :unprocessable_entity
      
    rescue StandardError => e
      # Handle any other errors
      Rails.logger.error "Onboarding workspace creation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: {
        error: 'Failed to create workspace. Please try again.'
      }, status: :internal_server_error
    end
  end

  # POST /api/v1/onboarding/complete
  def complete
    current_user.complete_onboarding!
    render json: { 
      message: 'Onboarding completed',
      completed_at: current_user.onboarding_completed_at
    }
  end

  # POST /api/v1/onboarding/reset (for admin/support use)
  def reset
    current_user.reset_onboarding!
    render json: { 
      message: 'Onboarding reset',
      current_step: current_user.current_onboarding_step
    }
  end
end