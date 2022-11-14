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

      if Settings.modules_appeals_api.supplemental_claims_enabled
        resources :supplemental_claims, only: %i[index create show] do
          collection do
            get 'schema'
            post 'validate'
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
    namespace :v0, defaults: { format: 'json' } do
      resources :api, only: [:index]

      docs_controller = '/appeals_api/docs/v2/docs'
      get 'hlr', to: "#{docs_controller}#hlr"
      get 'nod', to: "#{docs_controller}#nod"
      get 'sc', to: "#{docs_controller}#sc"
      get 'ci', to: "#{docs_controller}#ci"
      get 'la', to: "#{docs_controller}#la"
    end

    namespace :v1, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
      get 'appeals', to: 'docs#appeals_status'
    end

    namespace :v2, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
    end
  end

  namespace :notice_of_disagreements, defaults: { format: 'json' } do
    namespace :v0 do
      oauth_cpath = '/appeals_api/notice_of_disagreements/v0/notice_of_disagreements'

      get 'healthcheck', to: '/appeals_api/metadata#healthcheck'
      get 'upstream_healthcheck', to: '/appeals_api/metadata#mail_status_upstream_healthcheck'

      namespace :forms do
        resources '10182', only: %i[create show], controller: oauth_cpath do
          collection do
            post 'validate'
          end
        end
      end

      resources :evidence_submissions, only: %i[create show], controller: "#{oauth_cpath}/evidence_submissions"

      namespace :schemas, controller: oauth_cpath do
        get '10182', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end

  namespace :higher_level_reviews, defaults: { format: 'json' } do
    namespace :v0 do
      oauth_cpath = '/appeals_api/higher_level_reviews/v0/higher_level_reviews'

      get 'healthcheck', to: '/appeals_api/metadata#healthcheck'
      get 'upstream_healthcheck', to: '/appeals_api/metadata#mail_status_upstream_healthcheck'

      namespace :forms do
        resources '200996', only: %i[create show], controller: oauth_cpath do
          collection do
            post 'validate'
          end
        end
      end

      namespace :schemas, controller: oauth_cpath do
        get '200996', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end

  namespace :supplemental_claims, defaults: { format: 'json' } do
    namespace :v0 do
      oauth_cpath = '/appeals_api/supplemental_claims/v0/supplemental_claims'

      get 'healthcheck', to: '/appeals_api/metadata#healthcheck'
      get 'upstream_healthcheck', to: '/appeals_api/metadata#mail_status_upstream_healthcheck'

      namespace :forms do
        resources '200995', only: %i[create show], controller: oauth_cpath do
          collection do
            post 'validate'
          end
        end
      end

      resources :evidence_submissions, only: %i[create show], controller: "#{oauth_cpath}/evidence_submissions"

      namespace :schemas, controller: oauth_cpath do
        get '200995', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end

  namespace :contestable_issues, defaults: { format: 'json' } do
    namespace :v0 do
      oauth_cpath = '/appeals_api/contestable_issues/v0/contestable_issues'

      get 'contestable_issues/:decision_review_type', to: "#{oauth_cpath}#index"
      get 'healthcheck', to: '/appeals_api/metadata#healthcheck'
      get 'upstream_healthcheck', to: '/appeals_api/metadata#appeals_status_upstream_healthcheck'

      namespace :schemas, controller: oauth_cpath do
        get 'headers', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end

  namespace :legacy_appeals, defaults: { format: 'json' } do
    namespace :v0 do
      oauth_cpath = '/appeals_api/legacy_appeals/v0/legacy_appeals'

      get 'legacy_appeals', to: "#{oauth_cpath}#index"
      get 'healthcheck', to: '/appeals_api/metadata#healthcheck'
      get 'upstream_healthcheck', to: '/appeals_api/metadata#appeals_status_upstream_healthcheck'

      namespace :schemas, controller: oauth_cpath do
        get 'headers', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end
end
