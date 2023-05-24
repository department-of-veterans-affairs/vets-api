# frozen_string_literal: true

VBADocuments::Engine.routes.draw do
  get '/metadata', to: 'metadata#index'
  match '/v1/*path', to: 'application#cors_preflight', via: [:options]
  get '/v1/healthcheck', to: 'metadata#healthcheck'
  get '/v2/healthcheck', to: 'metadata#healthcheck'
  get '/v1/upstream_healthcheck', to: 'metadata#upstream_healthcheck'

  post '/v2/uploads/submit', to: 'v2/uploads#submit' if Settings.vba_documents.v2_upload_endpoint_enabled

  namespace :internal, defaults: { format: 'json' } do
    namespace :v1 do
      resources :upload_complete, only: [:create]
    end
  end

  if Settings.vba_documents.v2_enabled
    namespace :v2, defaults: { format: 'json' } do
      resources :uploads, only: %i[create show] do
        get 'download', to: 'uploads#download'
        collection do
          resource :report, only: %i[create]
        end
      end
    end
  end

  namespace :v1, defaults: { format: 'json' } do
    post '/uploads/validate_document', to: 'uploads#validate_document'

    resources :uploads, only: %i[create show] do
      get 'download', to: 'uploads#download'
      collection do
        resource :report, only: %i[create]
      end
    end
  end

  namespace :docs do
    namespace :v1 do
      resources :api, only: [:index]
    end

    namespace :v2 do
      resources :api, only: [:index]
    end
  end
end
