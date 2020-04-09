# frozen_string_literal: true

AppealsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :appeals, only: [:index]
    get 'healthcheck', to: 'appeals#healthcheck'
  end

  namespace :v1, defaults: { format: 'json' } do
    namespace :decision_review do
      resources :contestable_issues, only: [:index]
      resources :higher_level_reviews, only: %i[create] do
        collection do
          get 'schema', to: 'higher_level_reviews#schema'
          post 'validate', to: 'higher_level_reviews#validate'
        end
      end
    end
  end

  namespace :docs do
    namespace :v0 do
      resources :api, only: [:index]
    end
    namespace :v1, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
    end
  end
end
