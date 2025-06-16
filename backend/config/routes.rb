# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'uploads/create'
      get 'uploads/show'
      get 'uploads/update'
      get 'uploads/destroy'
      # Authentication routes
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      get 'auth/current', to: 'auth#current'

      # User management routes
      resources :users, only: [:index, :show, :update, :destroy]

      # Workspace management with nested containers and assets
      resources :workspaces do
        # Nested containers for workspace-scoped operations
        resources :containers, only: [:index, :create]
        
        # Nested assets for workspace-scoped operations
        resources :assets, only: [:index, :create]
        
        get :tree, to: 'containers#tree'

        # Nested uploads for workspace-scoped operations
        resources :uploads, only: [:index, :create]

        # Nested roles for workspace collaboration
        resources :roles, only: [:index, :create, :update, :destroy]
      end

      # Standalone container operations (show, update, delete)
      resources :containers, only: [:show, :update, :destroy]
      
      # Standalone upload session operations (show, update, delete)
      resources :uploads, only: [:show, :update, :destroy]

      # Container assets - custom route
      get 'containers/:container_id/assets', to: 'assets#container_assets'

      # Standalone asset operations (show, update, delete, download)
      resources :assets, only: [:show, :update, :destroy] do
        member do
          get :download
        end
      end

      # Simplified onboarding routes
      scope :onboarding do
        get :status, to: 'onboarding#status'
        post :start, to: 'onboarding#start'
        post :complete, to: 'onboarding#complete'
        post :reset, to: 'onboarding#reset'
      end
    end
  end
end