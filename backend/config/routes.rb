Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication routes
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      get 'auth/current', to: 'auth#current'

      # User management routes
      resources :users, only: [:index, :show, :update, :destroy]

      # Workspace management with nested collaboration
      resources :workspaces do
        # Nested roles for workspace collaboration
        resources :roles, only: [:index, :create, :update, :destroy]
      end

      # Simplified onboarding routes
      scope :onboarding do
        get :status, to: 'onboarding#status'
        post :start, to: 'onboarding#start'
        post :complete, to: 'onboarding#complete'
        post :reset, to: 'onboarding#reset'
        # Removed skip route - frontend calls complete directly
      end
    end
  end
end