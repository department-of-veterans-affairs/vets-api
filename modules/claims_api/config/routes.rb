# frozen_string_literal: true

ClaimsApi::Engine.routes.draw do
  match '/metadata', to: 'metadata#index', via: [:get]
  match '/v0/healthcheck', to: 'metadata#healthcheck', via: [:get]
  match '/v1/healthcheck', to: 'metadata#healthcheck', via: [:get]
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  match '/v1/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :claims, only: %i[index show]
    namespace :forms do
      ## 526 Forms
      get '526', to: 'disability_compensation#schema'
      post '526', to: 'disability_compensation#submit_form_526'
      post '526/validate', to: 'disability_compensation#validate_form_526'
      post '526/:id/attachments', to: 'disability_compensation#upload_supporting_documents'
      ## 0966 Forms
      get '0966', to: 'intent_to_file#schema'
      post '0966', to: 'intent_to_file#submit_form_0966'
      get '0966/active', to: 'intent_to_file#active'
      ## 2122 Forms
      get '2122', to: 'power_of_attorney#schema'
      post '2122', to: 'power_of_attorney#submit_form_2122'
      get '2122/status', to: 'power_of_attorney#status'
    end
  end

  namespace :v1, defaults: { format: 'json' } do
    resources :claims, only: %i[index show]
    namespace :forms do
      ## 526 Forms
      get '526', to: 'disability_compensation#schema'
      post '526', to: 'disability_compensation#submit_form_526'
      post '526/validate', to: 'disability_compensation#validate_form_526'
      post '526/:id/attachments', to: 'disability_compensation#upload_supporting_documents'
      ## 0966 Forms
      get '0966', to: 'intent_to_file#schema'
      post '0966', to: 'intent_to_file#submit_form_0966'
      get '0966/active', to: 'intent_to_file#active'
      ## 2122 Forms
      get '2122', to: 'power_of_attorney#schema'
      post '2122', to: 'power_of_attorney#submit_form_2122'
      get '2122/status', to: 'power_of_attorney#status'
    end
  end

  namespace :docs do
    namespace :v0 do
      get 'api', to: 'api#index'
    end

    namespace :v1 do
      get 'api', to: 'api#index'
    end
  end
end
