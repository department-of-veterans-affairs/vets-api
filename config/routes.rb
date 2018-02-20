# frozen_string_literal: true

require 'feature_flipper'
Rails.application.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  get '/saml/metadata', to: 'saml#metadata'
  get '/auth/saml/logout', to: 'v0/sessions#saml_logout_callback', as: 'saml_logout'
  post '/auth/saml/callback', to: 'v0/sessions#saml_callback', module: 'v0'

  namespace :v0, defaults: { format: 'json' } do
    resources :in_progress_forms, only: %i[index show update destroy]
    resource :claim_documents, only: [:create]
    resource :claim_attachments, only: [:create], controller: :claim_documents

    resources :letters, only: [:index] do
      collection do
        get 'beneficiary', to: 'letters#beneficiary'
        post ':id', to: 'letters#download'
      end
    end

    resource :sessions, only: :destroy do
      get :authn_urls, on: :collection
      get :multifactor, on: :member
      get :identity_proof, on: :member
      post :saml_callback, to: 'sessions#saml_callback'
      post :saml_slo_callback, to: 'sessions#saml_slo_callback'
    end

    resource :user, only: [:show]
    resource :post911_gi_bill_status, only: [:show]
    resource :feedback, only: [:create]

    resource :education_benefits_claims, only: [:create] do
      collection do
        post(':form_type', action: :create, as: :form_type)
      end
    end

    resource :health_care_applications, only: [:create] do
      collection do
        get(:healthcheck)
      end
    end

    if Settings.pension_burial.upload.enabled
      resource :pension_claims, only: [:create]
      resource :burial_claims, only: [:create]
    end

    resources :evss_claims, only: %i[index show] do
      post :request_decision, on: :member
      resources :documents, only: [:create]
    end

    get 'welcome', to: 'example#welcome', as: :welcome
    get 'limited', to: 'example#limited', as: :limited
    get 'status', to: 'admin#status'

    resources :maintenance_windows, only: [:index]

    resources :prescriptions, only: %i[index show], defaults: { format: :json } do
      get :active, to: 'prescriptions#index', on: :collection, defaults: { refill_status: 'active' }
      patch :refill, to: 'prescriptions#refill', on: :member
      resources :trackings, only: :index, controller: :trackings
      collection do
        resource :preferences, only: %i[show update], controller: 'prescription_preferences'
      end
    end

    resource :health_records, only: [:create], defaults: { format: :json } do
      get :refresh, to: 'health_records#refresh', on: :collection
      get :eligible_data_classes, to: 'health_records#eligible_data_classes', on: :collection
      get :show, controller: 'health_record_contents', on: :collection
    end

    resources :appeals, only: [:index]
    get 'appeals_v2', to: 'appeals#index_v2', as: :appeals_v2

    scope :messaging do
      scope :health do
        resources :triage_teams, only: [:index], defaults: { format: :json }, path: 'recipients'

        resources :folders, only: %i[index show create destroy], defaults: { format: :json } do
          resources :messages, only: [:index], defaults: { format: :json }
        end

        resources :messages, only: %i[show create destroy], defaults: { format: :json } do
          get :thread, on: :member
          get :categories, on: :collection
          patch :move, on: :member
          post :reply, on: :member
          resources :attachments, only: [:show], defaults: { format: :json }
        end

        resources :message_drafts, only: %i[create update], defaults: { format: :json } do
          post ':reply_id/replydraft', on: :collection, action: :create_reply_draft, as: :create_reply
          put ':reply_id/replydraft/:draft_id', on: :collection, action: :update_reply_draft, as: :update_reply
        end

        resource :preferences, only: %i[show update], controller: 'messaging_preferences'
      end
    end

    scope :facilities, module: 'facilities' do
      resources :va, only: %i[index show], defaults: { format: :json }
    end

    scope :gi, module: 'gi' do
      resources :institutions, only: :show, defaults: { format: :json } do
        get :search, on: :collection
        get :autocomplete, on: :collection
      end

      resources :calculator_constants, only: :index, defaults: { format: :json }
    end

    scope :id_card do
      resource :attributes, only: [:show], controller: 'id_card_attributes'
      resource :announcement_subscription, only: [:create], controller: 'id_card_announcement_subscription'
    end

    namespace :preneeds do
      resources :cemeteries, only: :index, defaults: { format: :json }
      resources :states, only: :index, defaults: { format: :json }
      resources :attachment_types, only: :index, defaults: { format: :json }
      resources :discharge_types, only: :index, defaults: { format: :json }
      resources :military_ranks, only: :index, defaults: { format: :json }
      resources :branches_of_service, only: :index, defaults: { format: :json }
      resources :burial_forms, only: %i[new create], defaults: { format: :json }
      resources :preneed_attachments, only: :create
    end

    namespace :vic do
      resources :profile_photo_attachments, only: %i[create show]
      resources :supporting_documentation_attachments, only: :create
      resources :vic_submissions, only: %i[create show]
    end

    resource :address, only: %i[show update] do
      collection do
        get 'countries', to: 'addresses#countries'
        get 'states', to: 'addresses#states'
        # temporary
        get 'rds/countries', to: 'addresses#rds_countries'
        get 'rds/states', to: 'addresses#rds_states'
      end
    end

    resources :apidocs, only: [:index]

    get 'terms_and_conditions', to: 'terms_and_conditions#index'
    get 'terms_and_conditions/:name/versions/latest', to: 'terms_and_conditions#latest'
    get 'terms_and_conditions/:name/versions/latest/user_data', to: 'terms_and_conditions#latest_user_data'
    post 'terms_and_conditions/:name/versions/latest/user_data', to: 'terms_and_conditions#accept_latest'

    [
      'veteran_id_card',
      FormProfile::EMIS_PREFILL_KEY
    ].each do |feature|
      resource(
        :beta_registrations,
        path: "/beta_registration/#{feature}",
        only: %i[show create],
        defaults: { feature: feature }
      )
    end
  end

  root 'v0/example#index', module: 'v0'

  if Rails.env.development? || Settings.sidekiq_admin_panel
    require 'sidekiq/web'
    require 'sidekiq-scheduler/web'
    mount Sidekiq::Web, at: '/sidekiq'
  end

  # Supports retrieval of VIC photo uploads during local development
  get '/content/vic/*path', to: 'content/vic_local_uploads#find_file' if Rails.env.development?

  # This globs all unmatched routes and routes them as routing errors
  match '*path', to: 'application#routing_error', via: %i[get post put patch delete]
end
# rubocop:enable Metrics/BlockLength
