Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Debug routes (optional - remove in production)
      get 'debug', to: 'debug#index'
      get 'debug/current_user', to: 'debug#current_user_info'
      get 'debug/workspaces', to: 'debug#check_workspaces'
      
      # Authentication routes
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      get 'auth/current', to: 'auth#current'

      # Core workspace/project workflow
      resources :workspaces do
        resources :projects, only: [:index, :create]
      end

      resources :projects, only: [:show, :update, :destroy] do
        collection do
          get 'recent'
        end
        
        # Core music production features
        resources :track_versions, shallow: true
        resources :roles, only: [:index, :create]
      end

      # Standalone role management
      resources :roles, only: [:show, :update, :destroy]

      # Track version content management
      resources :track_versions, only: [:show, :update, :destroy] do
        resources :track_contents, shallow: true
      end

      resources :track_contents, only: [:show, :update, :destroy]
    end
  end
end