# frozen_string_literal: true

require 'flipper/admin_user_constraint'

Rails.application.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  match '/services/*path', to: 'application#cors_preflight', via: [:options]

  get '/saml/metadata', to: 'saml#metadata'
  get '/auth/saml/logout', to: 'v0/sessions#saml_logout_callback', as: 'saml_logout'
  post '/auth/saml/callback', to: 'v0/sessions#saml_callback', module: 'v0'
  get '/sessions/:type/new',
      to: 'v0/sessions#new',
      constraints: ->(request) { V0::SessionsController::REDIRECT_URLS.include?(request.path_parameters[:type]) }

  get '/v1/sessions/metadata', to: 'v1/sessions#metadata'
  post '/v1/sessions/callback', to: 'v1/sessions#saml_callback', module: 'v1'
  get '/v1/sessions/:type/new',
      to: 'v1/sessions#new',
      constraints: ->(request) { V1::SessionsController::REDIRECT_URLS.include?(request.path_parameters[:type]) }
  get '/v1/sessions/ssoe_logout', to: 'v1/sessions#ssoe_slo_callback'
  # don't use the word "tracker" in the url, as some ad blockers will prevent the call
  get '/v1/sessions/trace', to: 'v1/sessions#tracker'

  namespace :v0, defaults: { format: 'json' } do
    resources :appointments, only: :index
    resources :in_progress_forms, only: %i[index show update destroy]
    resource :claim_documents, only: [:create]
    resource :claim_attachments, only: [:create], controller: :claim_documents
    resources :debts, only: :index
    resources :debt_letters, only: %i[index show]
    resources :financial_status_reports, only: :create
    resources :education_career_counseling_claims, only: :create
    resources :veteran_readiness_employment_claims, only: :create

    resources :letters, only: [:index] do
      collection do
        get 'beneficiary', to: 'letters#beneficiary'
        post ':id', to: 'letters#download'
      end
    end

    resource :disability_compensation_form, only: [] do
      get 'rated_disabilities'
      get 'rating_info'
      get 'submission_status/:job_id', to: 'disability_compensation_forms#submission_status', as: 'submission_status'
      post 'submit_all_claim'
      get 'suggested_conditions'
      get 'user_submissions'
      get 'separation_locations'
    end

    post '/mvi_users/:id', to: 'mpi_users#submit'

    resource :upload_supporting_evidence, only: :create

    resource :sessions, only: [] do
      post :saml_callback, to: 'sessions#saml_callback'
      post :saml_slo_callback, to: 'sessions#saml_slo_callback'
    end

    resource :user, only: [:show]
    resource :post911_gi_bill_status, only: [:show]
    resource :vso_appointments, only: [:create]

    resource :education_benefits_claims, only: [:create] do
      collection do
        post(':form_type', action: :create, as: :form_type)
      end
    end

    resources :health_care_applications, only: %i[create show] do
      collection do
        get(:healthcheck)
        get(:enrollment_status)
      end
    end

    resource :hca_attachments, only: :create

    resources :caregivers_assistance_claims, only: :create
    post 'caregivers_assistance_claims/download_pdf', to: 'caregivers_assistance_claims#download_pdf'

    resources :dependents_applications, only: %i[create show] do
      collection do
        get(:disability_rating)
      end
    end

    if Settings.central_mail.upload.enabled
      resources :pension_claims, only: %i[create show]
      resources :burial_claims, only: %i[create show]
    end

    resources :efolder, only: %i[index show]

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
    put 'ppiu/payment_information', to: 'ppiu#update'

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

    resources :appeals, only: :index

    namespace :higher_level_reviews do
      get 'contestable_issues(/:benefit_type)', to: 'contestable_issues#index'
    end
    resources :higher_level_reviews, only: %i[create show]

    namespace :notice_of_disagreements do
      get 'contestable_issues', to: 'contestable_issues#index'
    end
    resources :notice_of_disagreements, only: %i[create show]

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
      resources :ccp, only: %i[index show], defaults: { format: :json }
      get 'suggested', to: 'va#suggested'
      get 'services', to: 'ccp#services'
    end

    scope :gi, module: 'gids' do
      resources :institutions, only: :show, defaults: { format: :json } do
        get :search, on: :collection
        get :autocomplete, on: :collection
        get :children, on: :member
      end

      resources :institution_programs, only: :index, defaults: { format: :json } do
        get :search, on: :collection
        get :autocomplete, on: :collection
      end

      resources :calculator_constants, only: :index, defaults: { format: :json }

      resources :yellow_ribbon_programs, only: :index, defaults: { format: :json }

      resources :zipcode_rates, only: :show, defaults: { format: :json }
    end

    scope :id_card do
      resource :attributes, only: [:show], controller: 'id_card_attributes'
      resource :announcement_subscription, only: [:create], controller: 'id_card_announcement_subscription'
    end

    namespace :mdot do
      resources :supplies, only: %i[create]
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
    end

    resources :gi_bill_feedbacks, only: %i[create show]

    resource :address, only: %i[show update] do
      collection do
        get 'countries', to: 'addresses#countries'
        get 'states', to: 'addresses#states'
      end
    end

    namespace :profile do
      resource :alternate_phone, only: %i[show create]
      resource :email, only: %i[show create]
      resource :full_name, only: :show
      resource :personal_information, only: :show
      resource :primary_phone, only: %i[show create]
      resource :service_history, only: :show
      resources :connected_applications, only: %i[index destroy]
      resource :valid_va_file_number, only: %i[show]
      resources :payment_history, only: %i[index]

      # Vet360 Routes
      resource :addresses, only: %i[create update destroy]
      resource :email_addresses, only: %i[create update destroy]
      resource :telephones, only: %i[create update destroy]
      resource :permissions, only: %i[create update destroy]
      resources :address_validation, only: :create
      post 'initialize_vet360_id', to: 'persons#initialize_vet360_id'
      get 'person/status/:transaction_id', to: 'persons#status', as: 'person/status'
      get 'status/:transaction_id', to: 'transactions#status'
      get 'status', to: 'transactions#statuses'

      resources :ch33_bank_accounts, only: %i[index]
      put 'ch33_bank_accounts', to: 'ch33_bank_accounts#update'
    end

    resources :search, only: :index

    get 'forms', to: 'forms#index'

    get 'profile/mailing_address', to: 'addresses#show'
    put 'profile/mailing_address', to: 'addresses#update'

    resources :backend_statuses, param: :service, only: %i[index show]

    resources :apidocs, only: [:index]

    get 'terms_and_conditions', to: 'terms_and_conditions#index'
    get 'terms_and_conditions/:name/versions/latest', to: 'terms_and_conditions#latest'
    get 'terms_and_conditions/:name/versions/latest/user_data', to: 'terms_and_conditions#latest_user_data'
    post 'terms_and_conditions/:name/versions/latest/user_data', to: 'terms_and_conditions#accept_latest'

    resource :mhv_account, only: %i[show create] do
      post :upgrade
    end

    resources :notifications, only: %i[create show update], param: :subject

    namespace :notifications do
      resources :dismissed_statuses, only: %i[show create update], param: :subject
    end

    resources :preferences, only: %i[index show], path: 'user/preferences/choices', param: :code
    resources :user_preferences, only: %i[create index], path: 'user/preferences', param: :code
    delete 'user/preferences/:code/delete_all', to: 'user_preferences#delete_all'
    get 'feature_toggles', to: 'feature_toggles#index'

    [
      'profile',
      'dashboard',
      'veteran_id_card',
      'all_claims',
      FormProfile::EMIS_PREFILL_KEY
    ].each do |feature|
      resource(
        :beta_registrations,
        path: "/beta_registration/#{feature}",
        only: %i[show create destroy],
        defaults: { feature: feature }
      )
    end

    namespace :coronavirus_chatbot do
      resource :tokens, only: :create
    end

    namespace :contact_us do
      resources :inquiries, only: %i[index create]
    end
  end

  namespace :v1, defaults: { format: 'json' } do
    resources :apidocs, only: [:index]

    resource :sessions, only: [] do
      post :saml_callback, to: 'sessions#saml_callback'
      post :saml_slo_callback, to: 'sessions#saml_slo_callback'
    end

    namespace :facilities, module: 'facilities' do
      resources :va, only: %i[index show]
      resources :ccp, only: %i[index show] do
        get 'specialties', on: :collection, to: 'ccp#specialties'
      end
      resources :va_ccp, only: [] do
        get 'urgent_care', on: :collection
      end
    end
  end

  root 'v0/example#index', module: 'v0'

  scope '/internal' do
    mount OpenidAuth::Engine, at: '/auth'
  end

  scope '/services' do
    mount AppsApi::Engine, at: '/apps'
    mount VBADocuments::Engine, at: '/vba_documents'
    mount AppealsApi::Engine, at: '/appeals'
    mount ClaimsApi::Engine, at: '/claims'
    mount Veteran::Engine, at: '/veteran'
    mount VAForms::Engine, at: '/va_forms'
    mount VeteranVerification::Engine, at: '/veteran_verification'
    mount VeteranConfirmation::Engine, at: '/veteran_confirmation'
  end

  mount HealthQuest::Engine, at: '/health_quest'
  mount VAOS::Engine, at: '/vaos'
  mount CovidResearch::Engine, at: '/covid-research'
  mount Mobile::Engine, at: '/mobile'
  mount CovidVaccine::Engine, at: '/covid_vaccine'

  if Rails.env.development? || Settings.sidekiq_admin_panel
    require 'sidekiq/web'
    require 'sidekiq-scheduler/web'
    require 'sidekiq/pro/web' if Gem.loaded_specs.key?('sidekiq-pro')
    require 'sidekiq-ent/web' if Gem.loaded_specs.key?('sidekiq-ent')
    mount Sidekiq::Web, at: '/sidekiq'
  end

  mount Flipper::UI.app(Flipper.instance) => '/flipper', constraints: Flipper::AdminUserConstraint.new

  # This globs all unmatched routes and routes them as routing errors
  match '*path', to: 'application#routing_error', via: %i[get post put patch delete]
end
