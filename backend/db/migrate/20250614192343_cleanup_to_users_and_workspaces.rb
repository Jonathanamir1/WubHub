class CleanupToUsersAndWorkspaces < ActiveRecord::Migration[7.1]
  def up
    puts "🧹 Starting database cleanup based on actual table structure..."
    
    # Drop tables in dependency order (children first, then parents)
    # Based on your foreign key analysis:
    
    # 1. Drop 'files' first (depends on containers)
    if table_exists?(:files)
      puts "🗑️  Dropping 'files' table..."
      drop_table :files
      puts "   ✅ Successfully dropped 'files'"
    end
    
    # 2. Drop 'file_attachments' (seems like another file-related table)
    if table_exists?(:file_attachments)
      puts "🗑️  Dropping 'file_attachments' table..."
      drop_table :file_attachments
      puts "   ✅ Successfully dropped 'file_attachments'"
    end
    
    # 3. Now we can safely drop 'containers' (no more dependencies)
    if table_exists?(:containers)
      puts "🗑️  Dropping 'containers' table..."
      drop_table :containers
      puts "   ✅ Successfully dropped 'containers'"
    end
    
    # Clean up user table - remove profile_image string column if it exists
    if column_exists?(:users, :profile_image)
      puts "🖼️  Removing profile_image string column (keeping Active Storage)..."
      remove_column :users, :profile_image
      puts "   ✅ Removed profile_image column"
    end
    
    # Ensure we have proper indexes
    puts "📊 Ensuring proper indexes exist..."
    
    # User indexes
    unless index_exists?(:users, :email, unique: true)
      puts "   Adding unique index on users.email..."
      add_index :users, :email, unique: true
    end
    
    unless index_exists?(:users, :username, unique: true)
      puts "   Adding unique index on users.username..."
      add_index :users, :username, unique: true
    end
    
    # Workspace indexes
    unless index_exists?(:workspaces, :user_id)
      puts "   Adding index on workspaces.user_id..."
      add_index :workspaces, :user_id
    end
    
    # Role indexes (keep the collaboration system)
    if table_exists?(:roles)
      unless index_exists?(:roles, :user_id)
        puts "   Adding index on roles.user_id..."
        add_index :roles, :user_id
      end
      
      unless index_exists?(:roles, [:roleable_type, :roleable_id])
        puts "   Adding polymorphic index on roles..."
        add_index :roles, [:roleable_type, :roleable_id], name: 'index_roles_on_roleable'
      end
    end
    
    # Privacy indexes (keep the privacy system)
    if table_exists?(:privacies)
      unless index_exists?(:privacies, :user_id)
        puts "   Adding index on privacies.user_id..."
        add_index :privacies, :user_id
      end
      
      unless index_exists?(:privacies, [:privatable_type, :privatable_id])
        puts "   Adding polymorphic index on privacies..."
        add_index :privacies, [:privatable_type, :privatable_id], name: 'index_privacies_on_privatable'
      end
      
      unless index_exists?(:privacies, [:privatable_type, :privatable_id], unique: true)
        puts "   Adding unique constraint on privacies..."
        add_index :privacies, [:privatable_type, :privatable_id], 
                  unique: true, 
                  name: 'index_privacies_on_privatable_type_and_privatable_id'
      end
    end
    
    puts "\n✅ Cleanup completed successfully!"
    puts "\n📋 Final table structure:"
    remaining_tables = connection.tables.sort
    remaining_tables.each { |table| puts "   ✅ #{table}" }
    
    puts "\n🎯 You now have a clean foundation with:"
    puts "   • Users (with authentication)"
    puts "   • Workspaces (with ownership)"
    puts "   • Roles (for collaboration)"
    puts "   • Privacies (for access control)"
    puts "   • Active Storage (for file uploads)"
    puts "   • Onboarding (for user flow)"
  end
  
  def down
    raise ActiveRecord::IrreversibleMigration, "This cleanup cannot be reversed."
  end
end