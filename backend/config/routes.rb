# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Debug routes
      get 'debug', to: 'debug#index'
      get 'debug/current_user', to: 'debug#current_user_info'
      get 'debug/workspaces', to: 'debug#check_workspaces'
      get 'auth/debug', to: 'auth#debug'
      
      # Authentication routes
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      get 'auth/current', to: 'auth#current'

      # User routes
      resources :users, only: [:show, :update]

      # Workspace routes
      resources :workspaces do
        resources :projects
      end

      # Project routes
      resources :projects do
        collection do
          get 'recent' # Add this route for fetching recent projects
        end
        resources :track_versions
      end

      # Track version routes
      resources :track_versions do
        resources :comments
        resources :track_contents
      end

      # Direct upload route
      get '/uploads/:signed_id/*filename', to: 'direct_uploads#show', as: :rails_blob
    end
  end
end