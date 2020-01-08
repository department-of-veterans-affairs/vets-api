# frozen_string_literal: true

AppealsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :appeals, only: [:index] do
      collection do
        get 'higher_level_reviews/:uuid', to: 'appeals#show_higher_level_review'
        post 'higher_level_reviews', to: 'appeals#create_higher_level_review'
        get 'intake_statuses/:intake_id', to: 'appeals#show_intake_status'
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
