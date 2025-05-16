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

      # Workspace routes
      resources :workspaces do
        resources :projects
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

      # Project routes
      resources :projects do
        collection do
          get 'recent'
        end
        resources :track_versions
      end

      # Track version routes
      resources :track_versions do
        resources :comments
        resources :track_contents
      end
    end
  end
end