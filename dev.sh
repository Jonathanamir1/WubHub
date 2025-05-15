#!/bin/bash
echo "Starting WubHub development servers..."

# Start Rails server in the background
cd backend
rails s &
RAILS_PID=$!

# Start Vite dev server in the background
cd ../frontend
npm run dev &
VITE_PID=$!

# Function to handle shutdown
function cleanup {
  echo "Shutting down servers..."
  kill $RAILS_PID
  kill $VITE_PID
  exit
}

# Trap SIGINT (Ctrl+C) and call cleanup
trap cleanup INT

# Keep script running
echo "Servers running. Press Ctrl+C to stop."
wait