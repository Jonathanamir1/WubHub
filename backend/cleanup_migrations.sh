#!/bin/bash
# WubHub Migration Cleanup - Based on your exact 21 migrations

echo "🧹 Cleaning up WubHub migrations..."
echo "Current: 21 migrations → Target: 12 clean migrations"
echo ""

# Step 1: Create archive directory
echo "📁 Creating archive directory..."
mkdir -p db/migrate/archived

# Step 2: Move migrations that are no longer needed
echo "🗑️ Moving obsolete migrations to archive..."

# Schema consistency checks (one-time fixes)
mv db/migrate/20250515102734_check_schema_consistency.rb db/migrate/archived/
echo "   ✅ Archived: check_schema_consistency.rb"

# Old visibility system (replaced by privacy system)
mv db/migrate/20250522150124_add_private_default_visability_on_creation.rb db/migrate/archived/
echo "   ✅ Archived: add_private_default_visability_on_creation.rb"

mv db/migrate/20250528110359_remove_visibility_from_workspace_and_project.rb db/migrate/archived/
echo "   ✅ Archived: remove_visibility_from_workspace_and_project.rb"

# File/container system (dropped by cleanup migration)
mv db/migrate/20250602110348_create_file_attachments.rb db/migrate/archived/
echo "   ✅ Archived: create_file_attachments.rb"

mv db/migrate/20250605083941_create_containers.rb db/migrate/archived/
echo "   ✅ Archived: create_containers.rb"

mv db/migrate/20250605083942_create_track_contents.rb db/migrate/archived/
echo "   ✅ Archived: create_track_contents.rb"

# Drop table migrations (already handled by cleanup)
mv db/migrate/20250605134925_drop_track_versions_table.rb db/migrate/archived/
echo "   ✅ Archived: drop_track_versions_table.rb"

mv db/migrate/20250605135211_drop_projects_table.rb db/migrate/archived/
echo "   ✅ Archived: drop_projects_table.rb"

# Tags for non-existent table
mv db/migrate/20250610092829_add_tags_to_track_contents.rb db/migrate/archived/
echo "   ✅ Archived: add_tags_to_track_contents.rb"

echo ""
echo "📋 Remaining migrations (should be 12):"
ls -1 db/migrate/*.rb | wc -l | xargs echo "   Count:"
echo ""
echo "📁 Clean migration list:"
ls -1 db/migrate/ | nl

echo ""
echo "🎯 Your clean foundation includes:"
echo "   ✅ Users (with authentication & onboarding)"
echo "   ✅ Workspaces (with privacy controls)"
echo "   ✅ Roles (for collaboration)"
echo "   ✅ Privacies (for access control)"
echo "   ✅ Active Storage (for file uploads)"
echo "   ✅ Proper indexes (for performance)"
echo ""
echo "🚀 Ready to build your new file/container system on this solid foundation!"