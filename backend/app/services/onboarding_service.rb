# app/services/onboarding_service.rb
class OnboardingService
  STEPS = [
    'welcome',
    'profile_setup', 
    'workspace_setup',
    'final_setup',
    'completed'
  ].freeze

  def initialize(user)
    @user = user
  end

  # Step Access Control
  def can_access_step?(step)
    return true if @user.onboarding_completed?
    return false unless step.in?(STEPS)
    
    current_step_index = STEPS.index(@user.current_onboarding_step) || 0
    target_step_index = STEPS.index(step) || 0
    
    # Can access current step and all previous steps
    target_step_index <= current_step_index
  end

  # Step Progression
  def advance_to_next_step!
    current_step = @user.current_onboarding_step
    next_step = next_step_for(current_step)
    
    return false if next_step.nil?
    
    if next_step == 'completed'
      complete_onboarding!
    else
      @user.update!(onboarding_step: next_step)
    end
    
    true
  end

  def complete_onboarding!
    @user.update!(
      onboarding_step: 'completed',
      onboarding_completed_at: Time.current
    )
  end

  def reset_to_step!(step)
    return false unless step.in?(STEPS)
    
    @user.update!(
      onboarding_step: step,
      onboarding_completed_at: nil
    )
  end

  # Progress Tracking
  def progress_percentage
    current_index = STEPS.index(@user.current_onboarding_step) || 0
    total_steps = STEPS.length - 1 # Don't count 'completed' as a step
    
    return 100 if @user.onboarding_completed?
    (current_index.to_f / total_steps * 100).round
  end

  # Step Requirements
  def can_complete_current_step?
    case @user.current_onboarding_step
    when 'welcome'
      true # Always can complete welcome
    when 'profile_setup'
      @user.name.present? && @user.email.present?
    when 'workspace_setup'
      @user.workspaces.exists?
    when 'final_setup'
      true # Always can complete final setup
    else
      false
    end
  end

  def missing_requirements_for_current_step
    case @user.current_onboarding_step
    when 'profile_setup'
      requirements = []
      requirements << 'Name is required' if @user.name.blank?
      requirements << 'Email is required' if @user.email.blank?
      requirements
    when 'workspace_setup'
      @user.workspaces.exists? ? [] : ['At least one workspace is required']
    else
      []
    end
  end

  # Step Information
  def current_step_info
    {
      step: @user.current_onboarding_step,
      title: step_title(@user.current_onboarding_step),
      description: step_description(@user.current_onboarding_step),
      can_complete: can_complete_current_step?,
      missing_requirements: missing_requirements_for_current_step,
      progress_percentage: progress_percentage
    }
  end

  private

  def next_step_for(current_step)
    current_index = STEPS.index(current_step)
    return nil if current_index.nil? || current_index >= STEPS.length - 1
    STEPS[current_index + 1]
  end

  def step_title(step)
    case step
    when 'welcome'
      'Welcome to WubHub!'
    when 'profile_setup'
      'Set Up Your Profile'
    when 'workspace_setup'
      'Create Your First Workspace'
    when 'final_setup'
      'Final Setup'
    when 'completed'
      'Welcome to WubHub!'
    else
      'Unknown Step'
    end
  end

  def step_description(step)
    case step
    when 'welcome'
      'Welcome to WubHub, the organizational tool for musicians. Let\'s get you set up!'
    when 'profile_setup'
      'Tell us a bit about yourself to personalize your experience.'
    when 'workspace_setup'
      'Create your first workspace to organize your music projects.'
    when 'final_setup'
      'Almost done! Let\'s finalize your setup.'
    when 'completed'
      'You\'re all set! Welcome to WubHub.'
    else
      'Complete this step to continue.'
    end
  end
end