# frozen_string_literal: true

require 'feature_flipper'
Rails.application.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  match '/services/*path', to: 'application#cors_preflight', via: [:options]

  get '/saml/metadata', to: 'saml#metadata'
  get '/auth/saml/logout', to: 'v0/sessions#saml_logout_callback', as: 'saml_logout'
  post '/auth/saml/callback', to: 'v0/sessions#saml_callback', module: 'v0'
  get '/sessions/:type/new',
      to: 'v0/sessions#new',
      constraints: ->(request) { V0::SessionsController::REDIRECT_URLS.include?(request.path_parameters[:type]) }

  namespace :v0, defaults: { format: 'json' } do
    resources :appointments, only: :index
    resources :in_progress_forms, only: %i[index show update destroy]
    resource :claim_documents, only: [:create]
    resource :claim_attachments, only: [:create], controller: :claim_documents

    resource :form526_opt_in, only: :create

    resources :letters, only: [:index] do
      collection do
        get 'beneficiary', to: 'letters#beneficiary'
        post ':id', to: 'letters#download'
      end
    end

    resource :disability_compensation_form, only: [] do
      get 'rated_disabilities'
      post 'submit'
      get 'submission_status/:job_id', to: 'disability_compensation_forms#submission_status', as: 'submission_status'
      get 'user_submissions'
      get 'suggested_conditions'
    end

    resource :upload_supporting_evidence, only: :create

    resource :sessions, only: [] do
      get  :logout, to: 'sessions#logout'
      post :saml_callback, to: 'sessions#saml_callback'
      post :saml_slo_callback, to: 'sessions#saml_slo_callback'
    end

    resource :user, only: [:show]
    resource :post911_gi_bill_status, only: [:show]
    resource :feedback, only: [:create]
    resource :vso_appointments, only: [:create]

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

    resource :dependents_applications, only: [:create]

    if Settings.central_mail.upload.enabled
      resources :pension_claims, only: %i[create show]
      resources :burial_claims, only: %i[create show]
    end

    resources :evss_claims, only: %i[index show] do
      post :request_decision, on: :member
      resources :documents, only: [:create]
    end

    resources :evss_claims_async, only: %i[index show]

    get 'intent_to_file', to: 'intent_to_files#index'
    get 'intent_to_file/:type/active', to: 'intent_to_files#active'
    post 'intent_to_file/:type', to: 'intent_to_files#submit'

    get 'welcome', to: 'example#welcome', as: :welcome
    get 'limited', to: 'example#limited', as: :limited
    get 'status', to: 'admin#status'

    get 'ppiu/payment_information', to: 'ppiu#index'

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
      resources :ccp, only: %i[show], defaults: { format: :json }
      get 'suggested', to: 'va#suggested'
      get 'services', to: 'ccp#services'
    end

    scope :gi, module: 'gi' do
      resources :institutions, only: :show, defaults: { format: :json } do
        get :search, on: :collection
        get :autocomplete, on: :collection
      end

      resources :calculator_constants, only: :index, defaults: { format: :json }
      resources :zipcode_rates, only: :show, defaults: { format: :json }
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

    resources :gi_bill_feedbacks, only: %i[create show]

    resource :address, only: %i[show update] do
      collection do
        if Settings.evss&.reference_data_service&.enabled
          get 'countries', to: 'addresses#rds_countries'
          get 'states', to: 'addresses#rds_states'
        else
          get 'countries', to: 'addresses#countries'
          get 'states', to: 'addresses#states'
        end
      end
    end

    resources :performance_monitorings, only: :create

    namespace :profile do
      resource :alternate_phone, only: %i[show create]
      resource :email, only: %i[show create]
      resource :full_name, only: :show
      resource :personal_information, only: :show
      resource :primary_phone, only: %i[show create]
      resource :service_history, only: :show

      # Vet360 Routes
      resource :addresses, only: %i[create update destroy]
      resource :email_addresses, only: %i[create update destroy]
      resource :telephones, only: %i[create update destroy]
      post 'initialize_vet360_id', to: 'persons#initialize_vet360_id'
      get 'person/status/:transaction_id', to: 'persons#status', as: 'person/status'
      get 'status/:transaction_id', to: 'transactions#status'
      get 'status', to: 'transactions#statuses'

      resource :reference_data, only: %i[show] do
        collection do
          get 'countries', to: 'reference_data#countries'
          get 'states', to: 'reference_data#states'
          get 'zipcodes', to: 'reference_data#zipcodes'
        end
      end
    end

    resources :search, only: :index

    get 'profile/mailing_address', to: 'addresses#show'
    put 'profile/mailing_address', to: 'addresses#update'

    resources :backend_statuses, param: :service, only: [:show]

    resources :apidocs, only: [:index]

    get 'terms_and_conditions', to: 'terms_and_conditions#index'
    get 'terms_and_conditions/:name/versions/latest', to: 'terms_and_conditions#latest'
    get 'terms_and_conditions/:name/versions/latest/user_data', to: 'terms_and_conditions#latest_user_data'
    post 'terms_and_conditions/:name/versions/latest/user_data', to: 'terms_and_conditions#accept_latest'

    resource :mhv_account, only: %i[show create] do
      post :upgrade
    end

    [
      'profile',
      'dashboard',
      'veteran_id_card',
      'claim_increase',
      FormProfile::EMIS_PREFILL_KEY
    ].each do |feature|
      resource(
        :beta_registrations,
        path: "/beta_registration/#{feature}",
        only: %i[show create destroy],
        defaults: { feature: feature }
      )
    end
  end

  root 'v0/example#index', module: 'v0'

  scope '/services' do
    mount VBADocuments::Engine, at: '/vba_documents'
    mount AppealsApi::Engine, at: '/appeals'
    mount VaFacilities::Engine, at: '/va_facilities'
    mount VeteranVerification::Engine, at: '/veteran_verification'
  end

  if Rails.env.development? || Settings.sidekiq_admin_panel
    require 'sidekiq/web'
    require 'sidekiq-scheduler/web'
    mount Sidekiq::Web, at: '/sidekiq'
  end

  # This globs all unmatched routes and routes them as routing errors
  match '*path', to: 'application#routing_error', via: %i[get post put patch delete]
end
# rubocop:enable Metrics/BlockLength
