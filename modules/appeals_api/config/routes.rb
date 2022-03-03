# frozen_string_literal: true

AppealsApi::Engine.routes.draw do
  get '/appeals_status/metadata', to: 'metadata#appeals_status'
  get '/decision_reviews/metadata', to: 'metadata#decision_reviews'
  get '/v0/healthcheck', to: 'metadata#healthcheck'
  get '/v1/healthcheck', to: 'metadata#healthcheck'
  get '/v2/healthcheck', to: 'metadata#healthcheck'
  get '/v0/upstream_healthcheck', to: 'metadata#appeals_status_upstream_healthcheck'
  get '/v1/upstream_healthcheck', to: 'metadata#decision_reviews_upstream_healthcheck'
  get '/v2/upstream_healthcheck', to: 'metadata#decision_reviews_upstream_healthcheck'
  get '/v0/appeals', to: 'v0/appeals#index'

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

      namespace :notice_of_disagreements do
        resources :evidence_submissions, only: %i[create show]
      end

      resources :notice_of_disagreements, only: %i[create]

      get 'legacy_appeals', to: 'legacy_appeals#index' if Settings.modules_appeals_api.legacy_appeals_enabled

      if Settings.modules_appeals_api.supplemental_claims_enabled
        resources :supplemental_claims, only: %i[create show] do
          collection do
            get 'schema', to: 'supplemental_claims#schema'
          end
        end
      end

      if Settings.modules_appeals_api.supplemental_claims_enabled
        namespace :supplemental_claims do
          resources :evidence_submissions, only: %i[create show]
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
