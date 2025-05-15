# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
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