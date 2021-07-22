# frozen_string_literal: true

VBADocuments::Engine.routes.draw do
  match '/metadata', to: 'metadata#index', via: [:get]
  match '/v0/healthcheck', to: 'metadata#healthcheck', via: [:get]
  match '/v1/healthcheck', to: 'metadata#healthcheck', via: [:get]
  match '/v0/upstream_healthcheck', to: 'metadata#upstream_healthcheck', via: [:get]
  match '/v1/upstream_healthcheck', to: 'metadata#upstream_healthcheck', via: [:get]
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
  match '/v1/*path', to: 'application#cors_preflight', via: [:options]

  match '/v2/uploads/submit', to: 'v2/uploads#submit', via: [:post] if Settings.vba_documents.v2_upload_endpoint_enabled

  namespace :internal, defaults: { format: 'json' } do
    namespace :v0 do
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
    resources :uploads, only: %i[create show] do
      get 'download', to: 'uploads#download'
      collection do
        resource :report, only: %i[create]
      end
    end
  end

  namespace :docs do
    namespace :v0 do
      resources :api, only: [:index]
    end

    namespace :v1 do
      resources :api, only: [:index]
    end

    namespace :v2 do
      resources :api, only: [:index]
    end
  end
end
