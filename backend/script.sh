#!/bin/bash
echo "🧪 TDD Step 1: Generate Models and Run Initial Tests"
echo "=================================================="

# Step 1a: Generate Container model
echo "📁 Generating Container model..."
rails generate model Container name:string path:text workspace:references parent_container:references metadata:jsonb

# Step 1b: Generate Asset model  
echo "📄 Generating Asset model..."
rails generate model Asset filename:string path:text file_size:bigint content_type:string metadata:jsonb workspace:references container:references user:references

# Step 1c: Run migrations
echo "🗄️ Running migrations..."
rails db:migrate

# Step 1d: Create our test files (copy from artifacts)
echo "📝 Creating test files..."
# You'll need to copy the spec files from the artifacts to:
# spec/models/container_spec.rb
# spec/models/asset_spec.rb
# spec/factories/containers.rb  
# spec/factories/assets.rb

echo "🧪 Running tests (should fail initially)..."
bundle exec rspec spec/models/container_spec.rb spec/models/asset_spec.rb -f d

echo ""
echo "🎯 Expected Result: Tests should FAIL because models don't have the methods yet"
echo "📋 Next: Implement model methods to make tests pass"