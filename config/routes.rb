# frozen_string_literal: true
Rails.application.routes.draw do
  # TODO(#45): add rack-cors middleware to streamline CORS config
  # Adding CORS preflight routes here for now to unblock front-end dev
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  get '/saml/metadata', to: 'saml#metadata'
  get '/auth/saml/callback', to: 'v0/sessions#saml_callback', module: 'v0'
  post '/auth/saml/callback', to: 'v0/sessions#saml_callback', module: 'v0'

  namespace :v0, defaults: { format: 'json' } do
    resource :sessions, only: [:new, :destroy] do
      get :saml_callback, to: 'sessions#saml_callback'
      get 'current', to: 'sessions#show'
    end

    get 'user', to: 'users#show'
    get 'profile', to: 'users#show'

    resource :education_benefits_claims, only: :create
    resources :disability_claims, only: [:index, :show] do
      post :request_decision, on: :member
      resources :documents, only: [:create]
    end

    get 'welcome', to: 'example#welcome', as: :welcome
    get 'status', to: 'admin#status'

    resources :prescriptions, only: [:index, :show], defaults: { format: :json } do
      get :active, to: 'prescriptions#index', on: :collection, defaults: { refill_status: 'active' }
      patch :refill, to: 'prescriptions#refill', on: :member
      resources :trackings, only: :index, controller: :trackings
    end

    scope :messaging do
      scope :health do
        resources :triage_teams, only: [:index], defaults: { format: :json }, path: 'recipients'

        resources :folders, only: [:index, :show, :create, :destroy], defaults: { format: :json } do
          resources :messages, only: [:index], defaults: { format: :json }
        end

        resources :messages, only: [:show, :create, :destroy], defaults: { format: :json } do
          get :thread, on: :member
          get :categories, on: :collection
          patch :move, on: :member
          post :reply, on: :member
        end

        resources :message_drafts, only: [:create, :update], defaults: { format: :json }
      end
    end

    scope :facilities, module: 'facilities' do
      resources :va, only: [:index, :show], defaults: { format: :json }
      resources :choiceact, only: [:index, :show], defaults: { format: :json }
    end
  end

  root 'v0/example#index', module: 'v0'

  if Rails.env.development? || (ENV['SIDEKIQ_ADMIN_PANEL'] == 'true')
    require 'sidekiq/web'
    mount Sidekiq::Web, at: '/sidekiq'
  end
end
