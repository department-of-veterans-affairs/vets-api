# frozen_string_literal: true

AppealsApi::Engine.routes.draw do
  match '/appeals_status/metadata', to: 'metadata#appeals_status', via: [:get]
  match '/decision_reviews/metadata', to: 'metadata#decision_reviews', via: [:get]
  match '/v0/healthcheck', to: 'metadata#healthcheck', via: [:get]
  match '/v1/healthcheck', to: 'metadata#healthcheck', via: [:get]
  match '/v2/healthcheck', to: 'metadata#healthcheck', via: [:get]
  match '/v0/upstream_healthcheck', to: 'metadata#appeals_status_upstream_healthcheck', via: [:get]
  match '/v1/upstream_healthcheck', to: 'metadata#decision_reviews_upstream_healthcheck', via: [:get]
  match '/v2/upstream_healthcheck', to: 'metadata#decision_reviews_upstream_healthcheck', via: [:get]
  match '/v0/appeals', to: 'v0/appeals#index', via: [:get]

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
      namespace :notice_of_disagreements do
        get 'contestable_issues', to: 'contestable_issues#index'
        resources :evidence_submissions, only: %i[create show]
      end
      resources :notice_of_disagreements, only: %i[create show] do
        collection do
          get 'schema'
          post 'validate'
        end
      end
    end
  end

  namespace :v2, defaults: { format: 'json' } do
    namespace :decision_reviews do
      get 'contestable_issues/:decision_review_type', to: 'contestable_issues#index'

      namespace :higher_level_reviews do
        get 'contestable_issues(/:benefit_type)', to: 'contestable_issues#index'
      end

      resources :higher_level_reviews, only: %i[create show] do
        collection do
          get 'schema'
          post 'validate'
        end
      end

      resources :notice_of_disagreements, only: %i[create show],
                                          controller: '/appeals_api/v1/decision_reviews/notice_of_disagreements' do
        collection do
          get 'schema'
          post 'validate'
        end
      end
    end
  end

  namespace :docs do
    namespace(:v0) { resources :api, only: [:index] }
    namespace :v1, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
    end

    namespace :v2, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
    end
  end
end
