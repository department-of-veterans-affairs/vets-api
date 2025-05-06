# frozen_string_literal: true

ClaimsApi::Engine.routes.draw do
  get '/metadata', to: 'metadata#index'
  get '/:version/upstream_healthcheck', to: 'upstream_healthcheck#index', defaults: { format: 'json' }
  get '/:version/upstream_healthcheck/faraday/corporate', to: 'upstream_faraday_healthcheck#corporate'
  get '/:version/upstream_healthcheck/faraday/claimant', to: 'upstream_faraday_healthcheck#claimant'
  get '/:version/upstream_healthcheck/faraday/itf', to: 'upstream_faraday_healthcheck#itf'
  match '/v1/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v1, defaults: { format: 'json' } do
    mount OkComputer::Engine, at: '/healthcheck'

    resources :claims, only: %i[index show]
    namespace :forms do
      ## 526 Forms
      get '526', to: 'disability_compensation#schema'
      post '526', to: 'disability_compensation#submit_form_526'
      put '526/:id', to: 'disability_compensation#upload_form_526'
      post '526/validate', to: 'disability_compensation#validate_form_526'
      post '526/:id/attachments', to: 'disability_compensation#upload_supporting_documents'
      ## 0966 Forms
      get '0966', to: 'intent_to_file#schema'
      post '0966', to: 'intent_to_file#submit_form_0966'
      get '0966/active', to: 'intent_to_file#active'
      post '0966/validate', to: 'intent_to_file#validate'
      ## 2122 Forms
      get '2122', to: 'power_of_attorney#schema'
      post '2122', to: 'power_of_attorney#submit_form_2122'
      get '2122/active', to: 'power_of_attorney#active'
      put '2122/:id', to: 'power_of_attorney#upload'
      get '2122/:id', to: 'power_of_attorney#status'
      post '2122/validate', to: 'power_of_attorney#validate'
    end
  end

  namespace :v2, defaults: { format: 'json' } do
    mount OkComputer::Engine, at: '/healthcheck'

    namespace :veterans do
      get '/:veteranId/claims', to: 'claims#index'
      get '/:veteranId/claims/:id', to: 'claims#show'
      post '/:veteranId/claims/:id/5103', to: 'evidence_waiver#submit'
      ## 2122 Forms
      scope module: 'power_of_attorney', path: '' do
        get '/:veteranId/power-of-attorney', to: 'base#show'
        post '/:veteranId/2122/validate', to: 'organization#validate'
        post '/:veteranId/2122', to: 'organization#submit'
        post '/:veteranId/2122a/validate', to: 'individual#validate'
        post '/:veteranId/2122a', to: 'individual#submit'
        get '/:veteranId/power-of-attorney/:id', to: 'base#status'
        # Power of Attorney Requests
        post '/:veteranId/power-of-attorney-request', to: 'request#create'
        post '/power-of-attorney-requests', to: 'request#index'
        get '/power-of-attorney-requests/:id', to: 'request#show'
        post '/power-of-attorney-requests/:id/decide', to: 'request#decide'
      end
      ## 0966 Forms
      get '/:veteranId/intent-to-file/:type', to: 'intent_to_file#type'
      post '/:veteranId/intent-to-file', to: 'intent_to_file#submit'
      post '/:veteranId/intent-to-file/validate', to: 'intent_to_file#validate'
      ## 526 Forms
      post '/:veteranId/526/validate', to: 'disability_compensation#validate'
      post '/:veteranId/526/generatePDF/minimum-validations', to: 'disability_compensation#generate_pdf'
      post '/:veteranId/526/synchronous', to: 'disability_compensation#synchronous'
    end
  end

  namespace :docs do
    mount Rswag::Ui::Engine => 'swagger'

    namespace :v1 do
      get 'api', to: 'api#index'
    end

    namespace :v2 do
      get 'api', to: 'api#index'
    end
  end
end
