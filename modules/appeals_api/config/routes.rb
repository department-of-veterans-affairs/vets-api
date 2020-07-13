# frozen_string_literal: true

AppealsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  match '/v0/healthcheck', to: 'metadata#healthcheck', via: [:get]
  match '/v1/healthcheck', to: 'metadata#healthcheck', via: [:get]

  namespace :v0, defaults: { format: 'json' } do
    resources :appeals, only: [:index]
  end

  namespace :v1, defaults: { format: 'json' } do
    namespace :decision_reviews do
      namespace :higher_level_reviews do
        get 'contestable_issues(/:benefit_type)', to: 'contestable_issues#index'
      end
      resources :higher_level_reviews, only: %i[create show] do
        collection do
          get 'schema', to: 'higher_level_reviews#schema'
          post 'validate', to: 'higher_level_reviews#validate'
        end
      end
    end
  end

  namespace :docs do
    namespace(:v0) { resources :api, only: [:index] }
    namespace :v1, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
    end
  end
end
