#!/bin/bash

# Check if we want to run R2 integration tests
if [[ "$1" == "--r2" ]]; then
    echo "🔗 Running R2 Integration Tests with development environment..."
    docker compose exec backend env RAILS_ENV=development bundle exec rspec --tag r2_integration -fd
else
    # Normal test run - EXPLICITLY exclude R2 tests
    docker compose exec backend env RAILS_ENV=test bundle exec rspec --tag ~r2_integration "$@"
fi