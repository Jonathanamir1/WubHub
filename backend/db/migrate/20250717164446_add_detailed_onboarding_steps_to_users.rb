class AddDetailedOnboardingStepsToUsers < ActiveRecord::Migration[7.1]
  def up
    # Step 1: Add new column to store additional onboarding information
    add_column :users, :onboarding_data, :text
    
    # Step 2: Convert existing users to new onboarding system
    # This loops through ALL existing users and updates their onboarding_step
    User.find_each do |user|
      case user.onboarding_step
      when 'not_started'
        # Old: User hasn't started onboarding
        # New: User should see welcome screen first
        user.update_columns(
          onboarding_step: 'welcome',
          onboarding_data: {}.to_json  # Empty JSON object
        )
      when 'workspace_creation'  
        # Old: User was in middle of creating workspace
        # New: User is in workspace_setup step (more detailed)
        user.update_columns(
          onboarding_step: 'workspace_setup',
          onboarding_data: {}.to_json
        )
      when 'completed'
        # Old: User finished onboarding
        # New: User completed all steps - mark which steps they "completed"
        user.update_columns(
          onboarding_step: 'completed',
          onboarding_data: { 
            completed_steps: ['welcome', 'profile_setup', 'workspace_setup', 'final_setup'] 
          }.to_json
        )
      else
        # Safety net: If user has weird/invalid onboarding_step, reset to welcome
        user.update_columns(
          onboarding_step: 'welcome',
          onboarding_data: {}.to_json
        )
      end
    end
  end

  def down
    # This reverses the migration if we need to rollback
    User.find_each do |user|
      case user.onboarding_step
      when 'welcome'
        user.update_column(:onboarding_step, 'not_started')
      when 'profile_setup', 'workspace_setup', 'final_setup'
        user.update_column(:onboarding_step, 'workspace_creation')
      when 'completed'
        user.update_column(:onboarding_step, 'completed')
      end
    end
    
    # Remove the new column
    remove_column :users, :onboarding_data
  end
end