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

      # User management routes
      resources :users, only: [:index, :show, :update, :destroy]

      # Core workspace/container workflow
      resources :workspaces do
        resources :containers, only: [:index, :create]  
      end

      #Core container/track_content
      resources :containers do
        resources :track_contents, only: [:index, :create]
      end

      # Standalone role management
      resources :roles, only: [:show, :update, :destroy]

    end
  end
end