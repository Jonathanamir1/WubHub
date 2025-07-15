# config/routes.rb
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
      post 'auth/google', to: 'auth#google'
      
      # User management routes
      resources :users, only: [:index, :show, :update, :destroy]

      # Core workspace/container workflow
      resources :workspaces do
        resources :containers, only: [:index, :create]
        # Assets routes under workspaces
        resources :assets, only: [:index, :create]
        # Uploads routes under workspaces
        resources :uploads, only: [:index, :create]
        # Nested roles for workspace collaboration
        resources :roles, only: [:index, :create, :update, :destroy]
      end
      
      # Tree route outside of resources to match test expectation
      get 'workspaces/:workspace_id/tree', to: 'containers#tree', as: :workspace_tree

      # Core container/track_content
      resources :containers do
        resources :track_contents, only: [:index, :create]
      end

      # Standalone container operations (show, update, delete)
      resources :containers, only: [:show, :update, :destroy]
      
      # Standalone upload session operations with chunk routes
      resources :uploads, only: [:show, :update, :destroy] do
        member do
          # Chunk upload routes
          post 'chunks/:chunk_number', to: 'chunks#upload'
          get 'chunks/:chunk_number', to: 'chunks#show'
          get 'chunks', to: 'chunks#index'
        end
      end

      # Container assets - custom route
      get 'containers/:container_id/assets', to: 'assets#container_assets'

      # Standalone asset operations (show, update, delete, download)
      resources :assets, only: [:show, :update, :destroy] do
        member do
          get :download
        end
      end

      # Onboarding routes
      scope :onboarding do
        get :status, to: 'onboarding#status'
        post :start, to: 'onboarding#start'
        post :complete, to: 'onboarding#complete'
        post :reset, to: 'onboarding#reset'
        post :create_first_workspace, to: 'onboarding#create_first_workspace'
      end

      # Standalone role management
      resources :roles, only: [:show, :update, :destroy]

      get 'health', to: 'health#show'
    end
  end
end