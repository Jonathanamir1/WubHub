require 'spec_helper'

# SIMPLIFIED: Smart environment detection based on development tag
def determine_test_environment
  # Check for explicit development flag in test tags
  if RSpec.configuration.inclusion_filter[:development] == true
    return 'development'
  end
  
  # Check for explicit environment variable override
  if ENV['FORCE_TEST_ENV'] == 'development'
    return 'development'
  end
  
  # Default to test environment
  'test'
end

# Set environment based on conditions
ENV['RAILS_ENV'] = determine_test_environment

require_relative '../config/environment'

# Prevent database truncation if we abort a test early.
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
require 'factory_bot_rails'
require 'database_cleaner/active_record'

# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This can be changed in the Rakefile or by using
# the command line option.

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# Helper method for R2 configuration check
def r2_configured?
  %w[
    CLOUDFLARE_R2_ACCESS_KEY_ID
    CLOUDFLARE_R2_SECRET_ACCESS_KEY
    CLOUDFLARE_R2_BUCKET
    CLOUDFLARE_R2_ENDPOINT
  ].all? { |var| ENV[var].present? }
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = ["#{::Rails.root}/spec/fixtures"]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # Include Factory Bot methods
  config.include FactoryBot::Syntax::Methods

  # FIXED: Exclude development tests completely in test environment
  if Rails.env.test?
    config.filter_run_excluding :development
  end
  
  config.filter_run_when_matching :focus

  # ENHANCED: Environment-aware test setup with colored output
  config.before(:suite) do
    env_color = Rails.env.test? ? "\e[32m" : "\e[33m"  # Green for test, Yellow for development
    reset_color = "\e[0m"
    
    puts "#{env_color}🧪 Running tests in #{Rails.env.upcase} environment#{reset_color}"
    puts "#{env_color}📦 Active Storage Service: #{ActiveStorage::Blob.service.class.name}#{reset_color}"
    
    # Only show R2 info if we're in development
    if Rails.env.development? && ActiveStorage::Blob.service.respond_to?(:bucket)
      puts "#{env_color}🪣 R2 Bucket: #{ActiveStorage::Blob.service.bucket.name}#{reset_color}"
    end
    
    # ENHANCED: Environment-specific database cleaning
    DatabaseCleaner.allow_remote_database_url = true
  end

  # ENHANCED: Environment-aware database cleaning strategy
  config.before(:each) do
    if Rails.env.development?
      # Development tests might need truncation for R2 integration
      DatabaseCleaner.strategy = :truncation
    else
      # Test environment uses faster transactions
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
  
  # Skip R2 tests if R2 is not configured (even in development)
  config.before(:each, :r2_integration) do
    unless r2_configured?
      skip "R2 not configured - set CLOUDFLARE_R2_* environment variables"
    end
  end
end