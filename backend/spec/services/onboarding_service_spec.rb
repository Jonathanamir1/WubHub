# spec/services/onboarding_service_spec.rb
require 'rails_helper'

RSpec.describe OnboardingService, type: :service do
  let(:user) { create(:user, onboarding_step: 'welcome') }
  let(:service) { OnboardingService.new(user) }

  describe '#can_access_step?' do
    it 'allows access to current and previous steps' do
      user.update!(onboarding_step: 'profile_setup')
      service = OnboardingService.new(user)
      
      expect(service.can_access_step?('welcome')).to be true
      expect(service.can_access_step?('profile_setup')).to be true
      expect(service.can_access_step?('workspace_setup')).to be false
    end

    it 'allows completed users to access any step' do
      user.update!(onboarding_step: 'completed')
      service = OnboardingService.new(user)
      
      OnboardingService::STEPS.each do |step|
        expect(service.can_access_step?(step)).to be true
      end
    end
  end

  describe '#advance_to_next_step!' do
    it 'advances through steps correctly' do
      expect { service.advance_to_next_step! }
        .to change { user.reload.onboarding_step }
        .from('welcome').to('profile_setup')
    end

    it 'completes onboarding when advancing from final_setup' do
      user.update!(onboarding_step: 'final_setup')
      service = OnboardingService.new(user)
      
      service.advance_to_next_step!
      
      user.reload
      expect(user.onboarding_step).to eq('completed')
      expect(user.onboarding_completed_at).to be_present
    end
  end

  describe '#progress_percentage' do
    it 'calculates correct progress' do
      expect(OnboardingService.new(build(:user, onboarding_step: 'welcome')).progress_percentage).to eq(0)
      expect(OnboardingService.new(build(:user, onboarding_step: 'profile_setup')).progress_percentage).to eq(25)
      expect(OnboardingService.new(build(:user, onboarding_step: 'workspace_setup')).progress_percentage).to eq(50)
      expect(OnboardingService.new(build(:user, onboarding_step: 'final_setup')).progress_percentage).to eq(75)
      expect(OnboardingService.new(build(:user, onboarding_step: 'completed')).progress_percentage).to eq(100)
    end
  end

  describe '#can_complete_current_step?' do
    it 'returns true for welcome step' do
      expect(service.can_complete_current_step?).to be true
    end

    it 'checks profile requirements for profile_setup' do
      user.update!(onboarding_step: 'profile_setup')
      # Use update_column to bypass validations for testing
      user.update_column(:name, '')
      service = OnboardingService.new(user)
      
      expect(service.can_complete_current_step?).to be false
    end

    it 'checks workspace requirements for workspace_setup' do
      user.update!(onboarding_step: 'workspace_setup')
      service = OnboardingService.new(user)
      
      expect(service.can_complete_current_step?).to be false
      
      create(:workspace, user: user)
      expect(service.can_complete_current_step?).to be true
    end
  end

  describe '#current_step_info' do
    it 'returns comprehensive step information' do
      info = service.current_step_info
      
      expect(info).to include(
        :step, :title, :description, :can_complete, 
        :missing_requirements, :progress_percentage
      )
      expect(info[:step]).to eq('welcome')
      expect(info[:title]).to eq('Welcome to WubHub!')
    end
  end
end