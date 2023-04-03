# frozen_string_literal: true

require_relative './route_concerns'

AppealsApi::Engine.routes.draw do
  get '/appeals_status/metadata', to: 'metadata#appeals_status'
  get '/decision_reviews/metadata', to: 'metadata#decision_reviews'
  get '/v0/healthcheck', to: 'metadata#healthcheck'
  get '/v1/healthcheck', to: 'metadata#healthcheck'
  get '/v1/appeals_healthcheck', to: 'metadata#healthcheck'
  get '/v1/appeals_upstream_healthcheck', to: 'metadata#appeals_status_upstream_healthcheck'
  get '/v2/healthcheck', to: 'metadata#healthcheck'
  get '/v0/upstream_healthcheck', to: 'metadata#appeals_status_upstream_healthcheck'
  get '/v1/upstream_healthcheck', to: 'metadata#decision_reviews_upstream_healthcheck'
  get '/v2/upstream_healthcheck', to: 'metadata#decision_reviews_upstream_healthcheck'
  get '/v0/appeals', to: 'v0/appeals#index'
  get '/v1/appeals', to: 'v1/appeals#index'

  namespace :v1, defaults: { format: 'json' } do
    namespace :decision_reviews do
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

      resources :higher_level_reviews, only: %i[index create show] do
        collection do
          get 'schema'
          post 'validate'
        end
      end

      namespace :notice_of_disagreements do
        resources :evidence_submissions, only: %i[create show]
      end

      resources :notice_of_disagreements, only: %i[index create show] do
        collection do
          get 'schema'
          post 'validate'
        end
      end

      get 'legacy_appeals', to: 'legacy_appeals#index' if Settings.modules_appeals_api.legacy_appeals_enabled

      resources :supplemental_claims, only: %i[index create show] do
        collection do
          get 'schema'
          post 'validate'
        end
      end

      namespace :supplemental_claims do
        resources :evidence_submissions, only: %i[create show]
      end
    end
  end

  namespace :docs do
    namespace :v0, defaults: { format: 'json' } do
      resources :api, only: [:index]

      # Routes below are deprecated - they can be removed once they are no longer used:
      docs_controller = '/appeals_api/docs/v2/docs'
      get 'hlr', to: "#{docs_controller}#hlr"
      get 'nod', to: "#{docs_controller}#nod"
      get 'sc', to: "#{docs_controller}#sc"
      get 'ci', to: "#{docs_controller}#ci"
      get 'la', to: "#{docs_controller}#la"
      # ...end of deprecated routes
    end

    namespace :v1, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
      get 'appeals', to: 'docs#appeals_status'
    end

    namespace :v2, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
    end
  end

  concern :appeals_status_routes, AppealsApi::SharedRoutes::AppealsStatus
  concerns :appeals_status_routes, deprecated: true
  concerns :appeals_status_routes

  concern :notice_of_disagreements_routes, AppealsApi::SharedRoutes::NoticeOfDisagreements
  concerns :notice_of_disagreements_routes, deprecated: true
  concerns :notice_of_disagreements_routes

  concern :higher_level_reviews_routes, AppealsApi::SharedRoutes::HigherLevelReviews
  concerns :higher_level_reviews_routes, deprecated: true
  concerns :higher_level_reviews_routes

  concern :supplemental_claims_routes, AppealsApi::SharedRoutes::SupplementalClaims
  concerns :supplemental_claims_routes, deprecated: true
  concerns :supplemental_claims_routes

  concern :contestable_issues_routes, AppealsApi::SharedRoutes::ContestableIssues
  concerns :contestable_issues_routes, deprecated: true
  concerns :contestable_issues_routes

  concern :legacy_appeals_routes, AppealsApi::SharedRoutes::LegacyAppeals
  concerns :legacy_appeals_routes, deprecated: true
  concerns :legacy_appeals_routes
end
