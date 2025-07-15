# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
RUN_DEVELOPMENT=false
RSPEC_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --development|--dev)
            RUN_DEVELOPMENT=true
            shift
            ;;
        --help|-h)
            echo "WubHub Test Runner"
            echo ""
            echo "Usage: $0 [OPTIONS] [RSPEC_ARGS]"
            echo ""
            echo "OPTIONS:"
            echo "  --development, --dev      Run tests in development environment (includes R2, real services)"
            echo "  --help, -h               Show this help message"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                                    # Run all tests in test environment"
            echo "  $0 spec/models/user_spec.rb         # Run specific test file"
            echo "  $0 --development                     # Run all tests in development environment"
            echo "  $0 --dev spec/upload_spec.rb        # Run upload tests with R2 integration"
            echo "  $0 --tag focus                       # Run tests with focus tag"
            echo ""
            exit 0
            ;;
        *)
            RSPEC_ARGS+=("$1")
            shift
            ;;
    esac
done

# Determine environment and tags
if [[ "$RUN_DEVELOPMENT" == true ]]; then
    print_status "Running tests in development environment (includes R2, real services)"
    RAILS_ENV="development"
    RSPEC_TAGS="--tag development"
else
    print_status "Running tests in test environment (mocked services)"
    RAILS_ENV="test"
    RSPEC_TAGS="--tag ~development"  # Exclude development tests by default
fi

# Build the full command
DOCKER_CMD="docker compose exec backend"
ENV_CMD="env RAILS_ENV=$RAILS_ENV"
RSPEC_CMD="bundle exec rspec"

# Add tags if specified
if [[ -n "$RSPEC_TAGS" ]]; then
    RSPEC_CMD="$RSPEC_CMD $RSPEC_TAGS"
fi

# Add user arguments
if [[ ${#RSPEC_ARGS[@]} -gt 0 ]]; then
    RSPEC_CMD="$RSPEC_CMD ${RSPEC_ARGS[*]}"
fi

# Show what we're about to run
print_status "Environment: $RAILS_ENV"
print_status "Command: $DOCKER_CMD $ENV_CMD $RSPEC_CMD"
echo ""

# Run the command
$DOCKER_CMD $ENV_CMD $RSPEC_CMD