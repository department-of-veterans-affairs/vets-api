# frozen_string_literal: true
require 'feature_flipper'
Rails.application.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  get '/saml/metadata', to: 'saml#metadata'
  get '/auth/saml/logout', to: 'v0/sessions#saml_logout_callback', as: 'saml_logout'
  post '/auth/saml/callback', to: 'v0/sessions#saml_callback', module: 'v0'

  namespace :v0, defaults: { format: 'json' } do
    resource :sessions, only: [:new, :destroy] do
      post :saml_callback, to: 'sessions#saml_callback'
      post :saml_slo_callback, to: 'sessions#saml_slo_callback'
      get 'current', to: 'sessions#show'
    end

    get 'user', to: 'users#show'
    get 'profile', to: 'users#show'

    resource :education_benefits_claims, only: [:create] do
      get :index, to: 'education_benefits_claims#daily_file',
                  defaults: { format: :tar },
                  as: :daily_file,
                  constraints: ->(_) { FeatureFlipper.show_education_benefit_form? }
      get ':id', to: 'education_benefits_claims#show',
                 defaults: { format: :text },
                 as: :show,
                 id: /\d+/,
                 constraints: ->(_) { FeatureFlipper.show_education_benefit_form? }
    end

    resource :disability_rating, only: [:show]
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
          resources :attachments, only: [:show], defaults: { format: :json }
        end

        resources :message_drafts, only: [:create, :update], defaults: { format: :json } do
          post ':reply_id/replydraft', on: :collection, action: :create_reply_draft, as: :create_reply
          put ':reply_id/replydraft/:draft_id', on: :collection, action: :update_reply_draft, as: :update_reply
        end
      end
    end

    scope :facilities, module: 'facilities' do
      resources :va, only: [:index, :show], defaults: { format: :json }
    end
  end

  root 'v0/example#index', module: 'v0'

  if Rails.env.development? || (ENV['SIDEKIQ_ADMIN_PANEL'] == 'true')
    require 'sidekiq/web'
    require 'sidekiq-scheduler/web'
    mount Sidekiq::Web, at: '/sidekiq'
  end

  # This globs all unmatched routes and routes them as routing errors
  match '*path', to: 'application#routing_error', via: %i(get post put patch delete)
end
