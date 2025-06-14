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

      # Onboarding routes for workspace creation flow
      scope :onboarding do
        get :status, to: 'onboarding#status'
        post :start, to: 'onboarding#start'
        post :complete, to: 'onboarding#complete'
        post :skip, to: 'onboarding#skip'
        post :reset, to: 'onboarding#reset'
      end
    end
  end
end