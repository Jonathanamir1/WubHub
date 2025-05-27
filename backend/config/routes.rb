# backend/config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Debug routes
      get 'debug', to: 'debug#index'
      get 'debug/current_user', to: 'debug#current_user_info'
      get 'debug/workspaces', to: 'debug#check_workspaces'
      
      # Authentication routes
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      get 'auth/current', to: 'auth#current'

      # User routes
      resources :users, only: [:show, :update]

      # Workspace routes with nested projects
      resources :workspaces do
        resources :projects, only: [:index, :create]
      end

      # Projects routes - standalone and with nested resources
      resources :projects, only: [:show, :update, :destroy] do
        collection do
          get 'recent'
        end
        
        # Track versions
        resources :track_versions, shallow: true
        
        # Folders and files
        resources :folders do
          resources :audio_files
        end
        
      end

      # Workspace preferences routes
      resources :workspace_preferences, only: [:index] do
        collection do
          put :update_order
          put :update_favorites
          put :update_privacy
          put :update_collapsed_sections
        end
      end

            # Nested routes for project-specific role management
      resources :projects do
        resources :roles, only: [:index, :create]
      end

      # Standalone routes for individual role management (polymorphic)
      resources :roles, only: [:show, :update, :destroy]

      # Track version routes with nested track contents
      resources :track_versions, only: [:show, :update, :destroy] do
        resources :track_contents, shallow: true
        resources :comments, shallow: true
      end

      # Track content routes
      resources :track_contents, only: [:show, :update, :destroy]
      
      # Comment routes
      resources :comments, only: [:show, :update, :destroy]
      
      # Search routes
      get 'search/projects', to: 'search#projects'
      get 'search/workspaces', to: 'search#workspaces'
      get 'search/users', to: 'search#users'
      
      # File download routes
      get 'download/track_content/:id', to: 'download#track_content'
      get 'download/audio_file/:id', to: 'download#audio_file'
    end
  end
end