# frozen_string_literal: true

require 'flipper/admin_user_constraint'

Rails.application.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  match '/services/*path', to: 'application#cors_preflight', via: [:options]

  get '/v1/sessions/metadata', to: 'v1/sessions#metadata'
  post '/v1/sessions/callback', to: 'v1/sessions#saml_callback', module: 'v1'
  get '/v1/sessions/:type/new',
      to: 'v1/sessions#new',
      constraints: ->(request) { V1::SessionsController::REDIRECT_URLS.include?(request.path_parameters[:type]) }
  get '/v1/sessions/ssoe_logout', to: 'v1/sessions#ssoe_slo_callback'

  get '/v0/sign_in/authorize', to: 'v0/sign_in#authorize'
  get '/v0/sign_in/callback', to: 'v0/sign_in#callback'
  post '/v0/sign_in/refresh', to: 'v0/sign_in#refresh'
  post '/v0/sign_in/revoke', to: 'v0/sign_in#revoke'
  post '/v0/sign_in/token', to: 'v0/sign_in#token'
  get '/v0/sign_in/introspect', to: 'v0/sign_in#introspect'
  get '/v0/sign_in/logout', to: 'v0/sign_in#logout'
  get '/v0/sign_in/logingov_logout_proxy', to: 'v0/sign_in#logingov_logout_proxy'
  get '/v0/sign_in/revoke_all_sessions', to: 'v0/sign_in#revoke_all_sessions'

  get '/inherited_proofing/auth', to: 'inherited_proofing#auth'
  get '/inherited_proofing/user_attributes', to: 'inherited_proofing#user_attributes'
  get '/inherited_proofing/callback', to: 'inherited_proofing#callback'

  namespace :v0, defaults: { format: 'json' } do
    resources :onsite_notifications, only: %i[create index update]

    resources :appointments, only: :index
    resources :in_progress_forms, only: %i[index show update destroy]
    resources :disability_compensation_in_progress_forms, only: %i[index show update destroy]
    resource :claim_documents, only: [:create]
    resource :claim_attachments, only: [:create], controller: :claim_documents
    resources :debts, only: %i[index show]
    resources :debt_letters, only: %i[index show]
    resources :education_career_counseling_claims, only: :create
    resources :veteran_readiness_employment_claims, only: :create
    resource :virtual_agent_token, only: [:create], controller: :virtual_agent_token

    get 'form1095_bs/download_pdf/:tax_year', to: 'form1095_bs#download_pdf'
    get 'form1095_bs/download_txt/:tax_year', to: 'form1095_bs#download_txt'
    get 'form1095_bs/available_forms', to: 'form1095_bs#available_forms'

    get 'user_transition_availabilities', to: 'user_transition_availabilities#index'

    resources :medical_copays, only: %i[index show]
    get 'medical_copays/get_pdf_statement_by_id/:statement_id', to: 'medical_copays#get_pdf_statement_by_id'
    post 'medical_copays/send_new_statements_notifications', to: 'medical_copays#send_new_statements_notifications'

    resources :apps, only: %i[index show]
    scope_default = { category: 'unknown_category' }
    get 'apps/scopes/:category', to: 'apps#scopes', defaults: scope_default
    get 'apps/scopes', to: 'apps#scopes', defaults: scope_default

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
    get 'benefits_reference_data/*path', to: 'benefits_reference_data#get_data'

    resources :financial_status_reports, only: %i[create] do
      collection do
        get :download_pdf
      end
    end

    post '/mvi_users/:id', to: 'mpi_users#submit'

    resource :decision_review_evidence, only: :create
    resource :upload_supporting_evidence, only: :create

    resource :user, only: [:show]
    resource :post911_gi_bill_status, only: [:show]

    resource :education_benefits_claims, only: %i[create show] do
      collection do
        post(':form_type', action: :create, as: :form_type)
        get(:stem_claim_status)
      end
    end

    resources :health_care_applications, only: %i[create show] do
      collection do
        get(:healthcheck)
        get(:enrollment_status)
        get(:rating_info)
      end
    end

    resource :hca_attachments, only: :create

    resources :caregivers_assistance_claims, only: :create
    post 'caregivers_assistance_claims/download_pdf', to: 'caregivers_assistance_claims#download_pdf'

    namespace :form1010cg do
      resources :attachments, only: :create
    end

    resources :dependents_applications, only: %i[create show] do
      collection do
        get(:disability_rating)
      end
    end

    resources :dependents_verifications, only: %i[create index]

    if Settings.central_mail.upload.enabled
      resources :pension_claims, only: %i[create show]
      resources :burial_claims, only: %i[create show]
    end

    resources :benefits_claims, only: %i[index show]

    get 'claim_letters', to: 'claim_letters#index'
    get 'claim_letters/:document_id', to: 'claim_letters#show'

    resources :efolder, only: %i[index show]

    resources :evss_claims, only: %i[index show] do
      post :request_decision, on: :member
      resources :documents, only: [:create]
    end

    resources :evss_claims_async, only: %i[index show]

    namespace :virtual_agent do
      get 'claim', to: 'virtual_agent_claim#index'
      get 'claim/:id', to: 'virtual_agent_claim#show'
    end

    resources :virtual_agent_claim, only: %i[index]

    namespace :virtual_agent do
      get 'appeal', to: 'virtual_agent_appeal#index'
    end

    resources :virtual_agent_appeal, only: %i[index]

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
      resources :burial_forms, only: :create, defaults: { format: :json }
      resources :preneed_attachments, only: :create
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

      # Lighthouse
      namespace :direct_deposits do
        resource :disability_compensations, only: %i[show update]
      end

      # Vet360 Routes
      resource :addresses, only: %i[create update destroy] do
        collection do
          post :create_or_update
        end
      end
      resource :email_addresses, only: %i[create update destroy] do
        collection do
          post :create_or_update
        end
      end
      resource :telephones, only: %i[create update destroy] do
        collection do
          post :create_or_update
        end
      end
      resource :permissions, only: %i[create update destroy] do
        collection do
          post :create_or_update
        end
      end
      resources :address_validation, only: :create
      post 'initialize_vet360_id', to: 'persons#initialize_vet360_id'
      get 'person/status/:transaction_id', to: 'persons#status', as: 'person/status'
      get 'status/:transaction_id', to: 'transactions#status'
      get 'status', to: 'transactions#statuses'
      resources :communication_preferences, only: %i[index create update]

      resources :ch33_bank_accounts, only: %i[index]
      put 'ch33_bank_accounts', to: 'ch33_bank_accounts#update'
      resource :gender_identities, only: :update
      resource :preferred_names, only: :update
    end

    resources :search, only: :index
    resources :search_typeahead, only: :index
    resources :search_click_tracking, only: :create

    get 'forms', to: 'forms#index'

    get 'profile/mailing_address', to: 'addresses#show'
    put 'profile/mailing_address', to: 'addresses#update'

    resources :backend_statuses, param: :service, only: %i[index show]

    resources :apidocs, only: [:index]

    get 'terms_and_conditions', to: 'terms_and_conditions#index'
    get 'terms_and_conditions/:name/versions/latest', to: 'terms_and_conditions#latest'
    get 'terms_and_conditions/:name/versions/latest/user_data', to: 'terms_and_conditions#latest_user_data'
    post 'terms_and_conditions/:name/versions/latest/user_data', to: 'terms_and_conditions#accept_latest'

    get 'feature_toggles', to: 'feature_toggles#index'

    resource :mhv_opt_in_flags, only: %i[show create]

    namespace :contact_us do
      resources :inquiries, only: %i[index create]
    end

    namespace :coe do
      get 'status'
      get 'download_coe'
      get 'documents'
      get 'document_download/:id', action: 'document_download'
      post 'submit_coe_claim'
      post 'document_upload'
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
    end

    namespace :gi, module: 'gids' do
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

    namespace :higher_level_reviews do
      get 'contestable_issues(/:benefit_type)', to: 'contestable_issues#index'
    end
    resources :higher_level_reviews, only: %i[create show]

    namespace :notice_of_disagreements do
      get 'contestable_issues', to: 'contestable_issues#index'
    end
    resources :notice_of_disagreements, only: %i[create show]

    namespace :supplemental_claims do
      get 'contestable_issues(/:benefit_type)', to: 'contestable_issues#index'
    end
    resources :supplemental_claims, only: %i[create show]
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

  # Modules
  mount CheckIn::Engine, at: '/check_in'
  mount CovidResearch::Engine, at: '/covid-research'
  mount CovidVaccine::Engine, at: '/covid_vaccine'
  mount DebtsApi::Engine, at: '/debts_api'
  mount DhpConnectedDevices::Engine, at: '/dhp_connected_devices'
  mount FacilitiesApi::Engine, at: '/facilities_api'
  mount FormsApi::Engine, at: '/forms_api'
  mount HealthQuest::Engine, at: '/health_quest'
  mount IncomeLimits::Engine, at: '/income_limits'
  mount MebApi::Engine, at: '/meb_api'
  mount Mobile::Engine, at: '/mobile'
  mount MyHealth::Engine, at: '/my_health', as: 'my_health'
  mount VAOS::Engine, at: '/vaos'
  # End Modules

  require 'sidekiq/web'
  require 'sidekiq-scheduler/web'
  require 'sidekiq/pro/web' if Gem.loaded_specs.key?('sidekiq-pro')
  require 'sidekiq-ent/web' if Gem.loaded_specs.key?('sidekiq-ent')
  require 'github_authentication/sidekiq_web'
  require 'github_authentication/coverband_reporters_web'

  mount Sidekiq::Web, at: '/sidekiq'

  Sidekiq::Web.register GithubAuthentication::SidekiqWeb unless Rails.env.development? || Settings.sidekiq_admin_panel

  mount TestUserDashboard::Engine, at: '/test_user_dashboard' if Settings.test_user_dashboard.env == 'staging'

  if %w[test localhost development staging].include?(Settings.vsp_environment)
    mount MockedAuthentication::Engine, at: '/mocked_authentication'
  end

  mount Flipper::UI.app(Flipper.instance) => '/flipper', constraints: Flipper::AdminUserConstraint.new

  if Rails.env.production?
    require 'coverband'
    mount Coverband::Reporters::Web.new, at: '/coverband', constraints: GithubAuthentication::CoverbandReportersWeb.new
  end

  # This globs all unmatched routes and routes them as routing errors
  match '*path', to: 'application#routing_error', via: %i[get post put patch delete]
end
