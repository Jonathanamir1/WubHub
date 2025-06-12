class AddOnboardingToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_step, :string, default: 'not_started'
    add_column :users, :onboarding_skipped, :boolean, default: false
    
    add_index :users, :onboarding_completed_at
    add_index :users, :onboarding_step
  end
end