# frozen_string_literal: true

ClaimsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :claims, only: %i[index show]
    namespace :forms do
      ## 526 Forms
      post '526', to: 'disability_compensation#submit_form_526'
      post '526/:id/attachments', to: 'disability_compensation#upload_supporting_documents'
    end
  end

  namespace :v1, defaults: { format: 'json' } do
    resources :claims, only: %i[index show]
    namespace :forms do
      ## 526 Forms
      post '526', to: 'disability_compensation#submit_form_526'
      post '526/:id/attachments', to: 'disability_compensation#upload_supporting_documents'
    end
  end

  namespace :docs do
    namespace :v0 do
      get 'api', to: 'api#claims'
    end
  end
end
