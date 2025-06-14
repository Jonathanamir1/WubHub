# Generate this migration:
# rails generate migration RemoveOnboardingSkippedFromUsers

class RemoveOnboardingSkippedFromUsers < ActiveRecord::Migration[7.1]
  def up
    # First, update any users who have onboarding_skipped = true to be completed
    if column_exists?(:users, :onboarding_skipped)
      puts "🎯 Simplifying onboarding system..."
      puts "   Updating users who skipped onboarding to mark as completed..."
      
      # Convert skipped users to completed
      execute <<-SQL
        UPDATE users 
        SET onboarding_step = 'completed', 
            onboarding_completed_at = COALESCE(onboarding_completed_at, CURRENT_TIMESTAMP)
        WHERE onboarding_skipped = true
      SQL
      
      # Show how many users were updated
      skipped_count = execute("SELECT COUNT(*) FROM users WHERE onboarding_skipped = true").first['count']
      puts "   Updated #{skipped_count} users who had skipped onboarding"
      
      # Remove the redundant column
      remove_column :users, :onboarding_skipped
      puts "   ✅ Removed onboarding_skipped column"
      puts "   Now: skip onboarding = complete onboarding (much simpler!)"
    else
      puts "   onboarding_skipped column doesn't exist, nothing to do"
    end
  end
  
  def down
    # Add the column back if needed (though this shouldn't be necessary)
    add_column :users, :onboarding_skipped, :boolean, default: false
    add_index :users, :onboarding_skipped
  end
end