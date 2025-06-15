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