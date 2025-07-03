# spec/rails_helper.rb - Updated for development testing

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'development'  # Force development environment
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

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Include Factory Bot methods
  config.include FactoryBot::Syntax::Methods

  # Database Cleaner configuration for development testing
  config.before(:suite) do
    # Warn about development testing
    puts "\n🚨 Running tests in DEVELOPMENT environment"
    puts "🔧 Using development database and R2 configuration"
    puts "💾 Database: #{Rails.configuration.database_configuration[Rails.env]['database']}"
    puts "📤 Storage: #{ActiveStorage::Blob.service.class.name}"
    puts "=" * 60
    
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end

  config.after(:each) do |example|
    # Clean up any uploaded files after each test
    if defined?(ActiveStorage) && ActiveStorage::Blob.service.respond_to?(:bucket)
      cleanup_test_files_from_r2
    end
    
    DatabaseCleaner.clean
  end

  private

  def cleanup_test_files_from_r2
    # Only clean up files that were created during tests
    # Look for blobs created in the last few minutes during test runs
    recent_blobs = ActiveStorage::Blob.where('created_at > ?', 5.minutes.ago)
    
    recent_blobs.each do |blob|
      # Only delete test files (files with 'test' in the key/filename)
      if blob.key&.include?('test') || blob.filename.to_s.include?('test')
        begin
          blob.purge_later  # Use background job to clean up
        rescue => e
          Rails.logger.debug "Could not clean up test blob #{blob.id}: #{e.message}"
        end
      end
    end
  end
end