# frozen_string_literal: true

VBADocuments::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :uploads, only: %i[create show] do
      collection do
        resource :report, only: %i[create]
      end
    end
  end

  namespace :docs do
    namespace :v0 do
      resources :api, only: [:index]
    end
  end
end
