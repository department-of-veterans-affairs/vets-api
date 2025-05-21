# frozen_string_literal: true

require 'flipper/route_authorization_constraint'

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
  get '/v0/sign_in/authorize_sso', to: 'v0/sign_in#authorize_sso' unless Settings.vsp_environment == 'production'
  get '/v0/sign_in/callback', to: 'v0/sign_in#callback'
  post '/v0/sign_in/refresh', to: 'v0/sign_in#refresh'
  post '/v0/sign_in/revoke', to: 'v0/sign_in#revoke'
  post '/v0/sign_in/token', to: 'v0/sign_in#token'
  get '/v0/sign_in/logout', to: 'v0/sign_in#logout'
  get '/v0/sign_in/logingov_logout_proxy', to: 'v0/sign_in#logingov_logout_proxy'
  get '/v0/sign_in/revoke_all_sessions', to: 'v0/sign_in#revoke_all_sessions'

  namespace :sign_in do
    get '/openid_connect/certs', to: 'openid_connect_certificates#index'

    namespace :webhooks do
      post 'logingov/risc', to: 'logingov#risc'
    end

    unless Settings.vsp_environment == 'production'
      resources :client_configs, param: :client_id
      resources :service_account_configs, param: :service_account_id
      get '/user_info', to: 'user_info#show'
    end
  end

  namespace :sts do
    get '/terms_of_use/current_status', to: 'terms_of_use#current_status'
  end

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
    resources :user_actions, only: [:index]
    resources :veteran_readiness_employment_claims, only: :create
    resource :virtual_agent_token, only: [:create], controller: :virtual_agent_token
    resource :virtual_agent_token_msft, only: [:create], controller: :virtual_agent_token_msft
    resource :virtual_agent_token_nlu, only: [:create], controller: :virtual_agent_token_nlu
    resource :virtual_agent_jwt_token, only: [:create], controller: :virtual_agent_jwt_token
    resource :virtual_agent_speech_token, only: [:create], controller: :virtual_agent_speech_token

    get 'form1095_bs/download_pdf/:tax_year', to: 'form1095_bs#download_pdf'
    get 'form1095_bs/download_txt/:tax_year', to: 'form1095_bs#download_txt'
    get 'form1095_bs/available_forms', to: 'form1095_bs#available_forms'

    resources :medical_copays, only: %i[index show]
    get 'medical_copays/get_pdf_statement_by_id/:statement_id', to: 'medical_copays#get_pdf_statement_by_id'
    post 'medical_copays/send_statement_notifications', to: 'medical_copays#send_statement_notifications'

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

    resources :letters_discrepancy, only: [:index]

    resources :letters_generator, only: [:index] do
      collection do
        get 'beneficiary', to: 'letters_generator#beneficiary'
        post 'download/:id', to: 'letters_generator#download'
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

    post '/mvi_users/:id', to: 'mpi_users#submit'

    resource :upload_supporting_evidence, only: :create

    resource :user, only: [:show] do
      get 'icn', to: 'users#icn'
      collection do
        get 'credential_emails'
      end
      resource :mhv_user_account, only: [:show], controller: 'user/mhv_user_accounts'
    end

    resource :test_account_user_email, only: [:create]

    resource :veteran_onboarding, only: %i[show update]

    resource :education_benefits_claims, only: %i[create show] do
      collection do
        post(':form_type', action: :create, as: :form_type)
        get(:stem_claim_status)
        get('download_pdf/:id', action: :download_pdf, as: :download_pdf)
      end
    end

    resources :health_care_applications, only: %i[create show] do
      collection do
        get(:healthcheck)
        get(:enrollment_status)
        get(:rating_info)
        get(:facilities)
        post(:download_pdf)
      end
    end

    resource :hca_attachments, only: :create
    resource :form1010_ezr_attachments, only: :create

    resources :caregivers_assistance_claims, only: :create do
      collection do
        post(:facilities)
        post(:download_pdf)
      end
    end

    namespace :form1010cg do
      resources :attachments, only: :create
    end

    resources :dependents_applications, only: %i[create show] do
      collection do
        get(:disability_rating)
      end
    end

    resources :dependents_verifications, only: %i[create index]

    resources :benefits_claims, only: %i[index show] do
      post :submit5103, on: :member
      post 'benefits_documents', to: 'benefits_documents#create'
    end

    resources :evidence_submissions, only: %i[index]

    get 'claim_letters', to: 'claim_letters#index'
    get 'claim_letters/:document_id', to: 'claim_letters#show'

    get 'average_days_for_claim_completion', to: 'average_days_for_claim_completion#index'

    resources :efolder, only: %i[index show]

    resources :evss_claims, only: %i[index show] do
      post :request_decision, on: :member
      resources :documents, only: [:create]
    end

    resources :evss_claims_async, only: %i[index show]
    resources :evss_benefits_claims, only: %i[index show] unless Settings.vsp_environment == 'production'

    resource :rated_disabilities, only: %i[show]

    namespace :virtual_agent do
      get 'claims', to: 'virtual_agent_claim_status#index'
      get 'claims/:id', to: 'virtual_agent_claim_status#show'
    end

    get 'intent_to_file', to: 'intent_to_files#index'
    post 'intent_to_file/:type', to: 'intent_to_files#submit'

    get 'welcome', to: 'example#welcome', as: :welcome
    get 'limited', to: 'example#limited', as: :limited
    get 'status', to: 'admin#status'
    get 'healthcheck', to: 'example#healthcheck', as: :healthcheck
    get 'startup_healthcheck', to: 'example#startup_healthcheck', as: :startup_healthcheck

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

    namespace :my_va do
      resource :submission_statuses, only: :show
      resource :submission_pdf_urls, only: :create
    end

    namespace :profile do
      resource :full_name, only: :show
      resource :personal_information, only: :show
      resource :service_history, only: :show
      resources :connected_applications, only: %i[index destroy]
      resource :valid_va_file_number, only: %i[show]
      resources :payment_history, only: %i[index]
      resource :military_occupations, only: :show

      # Lighthouse
      resource :direct_deposits, only: %i[show update]
      resource :vet_verification_status, only: :show

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
      resources :contacts, only: %i[index]

      resource :gender_identities, only: :update
      resource :preferred_names, only: :update
    end

    resources :search, only: :index
    resources :search_typeahead, only: :index
    resources :search_click_tracking, only: :create

    get 'forms', to: 'forms#index'

    get 'profile/mailing_address', to: 'addresses#show'
    put 'profile/mailing_address', to: 'addresses#update'

    resources :backend_statuses, only: %i[index]

    resources :apidocs, only: [:index]

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

    unless Settings.vsp_environment == 'production'
      get 'terms_of_use_agreements/:icn/current_status', to: 'terms_of_use_agreements#current_status'
    end
    get 'terms_of_use_agreements/:version/latest', to: 'terms_of_use_agreements#latest'
    post 'terms_of_use_agreements/:version/accept', to: 'terms_of_use_agreements#accept'
    post 'terms_of_use_agreements/:version/accept_and_provision', to: 'terms_of_use_agreements#accept_and_provision'
    post 'terms_of_use_agreements/:version/decline', to: 'terms_of_use_agreements#decline'
    put 'terms_of_use_agreements/update_provisioning', to: 'terms_of_use_agreements#update_provisioning'

    resources :form1010_ezrs, only: %i[create]

    post 'map_services/:application/token', to: 'map_services#token', as: :map_services_token

    get 'banners', to: 'banners#by_path'
  end
  # end /v0

  namespace :v1, defaults: { format: 'json' } do
    resources :apidocs, only: [:index]

    namespace :profile do
      resource :military_info, only: :show, defaults: { format: :json }
    end

    resource :sessions, only: [] do
      post :saml_callback, to: 'sessions#saml_callback'
      post :saml_slo_callback, to: 'sessions#saml_slo_callback'
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

      namespace :lcpe do
        resources :lacs, only: %i[index show], defaults: { format: :json }
        resources :exams, only: %i[index show], defaults: { format: :json }
      end
    end

    resource :post911_gi_bill_status, only: [:show]

    scope format: false do
      resources :nod_callbacks, only: [:create], controller: :decision_review_notification_callbacks
    end
  end

  root 'v0/example#index', module: 'v0'

  scope '/services' do
    mount AppsApi::Engine, at: '/apps'
    mount VBADocuments::Engine, at: '/vba_documents'
    mount AppealsApi::Engine, at: '/appeals'
    mount ClaimsApi::Engine, at: '/claims'
    mount Veteran::Engine, at: '/veteran'
    mount VeteranConfirmation::Engine, at: '/veteran_confirmation'
  end

  # Modules
  mount AccreditedRepresentativePortal::Engine, at: '/accredited_representative_portal'
  mount AskVAApi::Engine, at: '/ask_va_api'
  mount Avs::Engine, at: '/avs'
  mount Burials::Engine, at: '/burials'
  mount CheckIn::Engine, at: '/check_in'
  mount DebtsApi::Engine, at: '/debts_api'
  mount DhpConnectedDevices::Engine, at: '/dhp_connected_devices'
  mount FacilitiesApi::Engine, at: '/facilities_api'
  mount IncomeAndAssets::Engine, at: '/income_and_assets'
  mount IvcChampva::Engine, at: '/ivc_champva'
  mount RepresentationManagement::Engine, at: '/representation_management'
  mount SimpleFormsApi::Engine, at: '/simple_forms_api'
  mount HealthQuest::Engine, at: '/health_quest'
  mount IncomeLimits::Engine, at: '/income_limits'
  mount MebApi::Engine, at: '/meb_api'
  mount Mobile::Engine, at: '/mobile'
  mount MyHealth::Engine, at: '/my_health', as: 'my_health'
  mount TravelPay::Engine, at: '/travel_pay'
  mount VRE::Engine, at: '/vre'
  mount VaNotify::Engine, at: '/va_notify'
  mount VAOS::Engine, at: '/vaos'
  mount Vye::Engine, at: '/vye'
  mount Pensions::Engine, at: '/pensions'
  mount DecisionReviews::Engine, at: '/decision_reviews'
  # End Modules

  require 'sidekiq/web'
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

  get '/flipper/logout', to: 'flipper#logout'
  get '/flipper/login', to: 'flipper#login'
  mount Flipper::UI.app(Flipper.instance) => '/flipper', constraints: Flipper::RouteAuthorizationConstraint

  unless Rails.env.test?
    mount Coverband::Reporters::Web.new, at: '/coverband', constraints: GithubAuthentication::CoverbandReportersWeb.new
  end

  get '/apple-touch-icon-:size.png', to: redirect('/apple-touch-icon.png')

  # This globs all unmatched routes and routes them as routing errors
  match '*path', to: 'application#routing_error', via: %i[get post put patch delete]
end
