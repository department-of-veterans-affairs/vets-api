# frozen_string_literal: true

AppealsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :appeals, only: [:index] do
      resources :higher_level_reviews, only: %i[show create], defaults: { format: :json } do
        get 'intake_status/:intake_id', to: 'appeals#intake_status'
      end
    end

    get 'healthcheck', to: 'appeals#healthcheck'
  end

  namespace :docs do
    namespace :v0 do
      resources :api, only: [:index]
    end
  end
end
