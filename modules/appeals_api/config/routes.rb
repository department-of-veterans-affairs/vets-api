# frozen_string_literal: true

AppealsApi::Engine.routes.draw do
  get '/appeals_status/metadata', to: 'metadata#appeals_status'
  get '/decision_reviews/metadata', to: 'metadata#decision_reviews'
  get '/v0/healthcheck', to: 'metadata#healthcheck' # Appeals Status v0
  get '/v1/healthcheck', to: 'metadata#healthcheck_s3' # Decision Reviews v1
  # TODO: Remove in favor of /v2/decision_reviews/healthcheck once routing changes made in API Gateway
  get '/v2/healthcheck', to: 'metadata#healthcheck_s3' # Decision Reviews v2
  get '/v0/upstream_healthcheck', to: 'metadata#appeals_status_upstream_healthcheck' # Appeals Status v0
  get '/v1/upstream_healthcheck', to: 'metadata#decision_reviews_upstream_healthcheck' # Decision Reviews v1
  # TODO: Remove in favor of /v2/decision_reviews/upstream_healthcheck once routing changes made in API Gateway
  get '/v2/upstream_healthcheck', to: 'metadata#decision_reviews_upstream_healthcheck' # Decision Reviews v2
  get '/v0/appeals', to: 'v0/appeals#index' # Appeals Status v0

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
      get 'docs', to: '/appeals_api/docs/v2/docs#decision_reviews'
      get 'healthcheck', to: '/appeals_api/metadata#healthcheck_s3'
      get 'upstream_healthcheck', to: '/appeals_api/metadata#decision_reviews_upstream_healthcheck'

      get 'contestable_issues/:decision_review_type', to: 'contestable_issues#index'

      namespace :higher_level_reviews do
        get 'contestable_issues(/:benefit_type)', to: 'contestable_issues#index'
      end

      resources :higher_level_reviews, only: %i[index create show] do
        collection do
          get 'schema'
          post 'validate'
          # get '/:id/download', action: 'download'
        end
      end

      namespace :notice_of_disagreements do
        resources :evidence_submissions, only: %i[create show]
      end

      resources :notice_of_disagreements, only: %i[index create show] do
        collection do
          get 'schema'
          post 'validate'
          # get '/:id/download', action: 'download'
        end
      end

      get 'legacy_appeals', to: 'legacy_appeals#index' if Settings.modules_appeals_api.legacy_appeals_enabled

      resources :supplemental_claims, only: %i[index create show] do
        collection do
          get 'schema'
          post 'validate'
          # get '/:id/download', action: 'download'
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
    end

    namespace :v1, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
    end

    # TODO: Remove in favor of /v2/decision_reviews/docs once routing changes made in API Gateway
    namespace :v2, defaults: { format: 'json' } do
      get 'decision_reviews', to: 'docs#decision_reviews'
    end
  end

  namespace :appeals_status, path: 'appeals-status', defaults: { format: 'json' } do
    namespace :v1, defaults: { format: 'json' } do
      get :appeals, to: '/appeals_api/v1/appeals#index'
      get :healthcheck, to: '/appeals_api/metadata#healthcheck'
      get :upstream_healthcheck,
          to: '/appeals_api/metadata#appeals_status_upstream_healthcheck',
          path: 'upstream-healthcheck'
      get :docs, to: '/appeals_api/docs/v1/docs#appeals_status'
    end
  end

  namespace :notice_of_disagreements, path: 'notice-of-disagreements', defaults: { format: 'json' } do
    namespace :v0 do
      controller_path = '/appeals_api/notice_of_disagreements/v0/notice_of_disagreements'

      get :healthcheck, to: '/appeals_api/metadata#healthcheck_s3'
      get :upstream_healthcheck,
          to: '/appeals_api/metadata#mail_status_upstream_healthcheck',
          path: 'upstream-healthcheck'
      get :docs, to: '/appeals_api/docs/v2/docs#nod'

      namespace :forms do
        resources '10182', only: %i[create show], controller: controller_path do
          collection do
            post 'validate'
            get '/:id/download', action: 'download'
          end
        end
      end

      resources :evidence_submissions,
                only: %i[create show],
                controller: "#{controller_path}/evidence_submissions",
                path: 'evidence-submissions'

      namespace :schemas, controller: controller_path do
        get '10182', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end

  namespace :higher_level_reviews, path: 'higher-level-reviews', defaults: { format: 'json' } do
    namespace :v0 do
      controller_path = '/appeals_api/higher_level_reviews/v0/higher_level_reviews'

      get :healthcheck, to: '/appeals_api/metadata#healthcheck'
      get :upstream_healthcheck,
          to: '/appeals_api/metadata#mail_status_upstream_healthcheck',
          path: 'upstream-healthcheck'
      get :docs, to: '/appeals_api/docs/v2/docs#hlr'

      namespace :forms do
        # NOTE: The index route will remain disabled until questions around claimant vs. veteran privacy are resolved
        resources '200996', only: %i[create show], controller: controller_path do
          collection do
            post 'validate'
            get '/:id/download', action: 'download'
          end
        end
      end

      namespace :schemas, controller: controller_path do
        get '200996', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end

  namespace :supplemental_claims, path: 'supplemental-claims', defaults: { format: 'json' } do
    namespace :v0 do
      controller_path = '/appeals_api/supplemental_claims/v0/supplemental_claims'

      get :healthcheck, to: '/appeals_api/metadata#healthcheck_s3'
      get :upstream_healthcheck,
          to: '/appeals_api/metadata#mail_status_upstream_healthcheck',
          path: 'upstream-healthcheck'
      get :docs, to: '/appeals_api/docs/v2/docs#sc'

      namespace :forms do
        # NOTE: The index route will remain disabled until questions around claimant vs. veteran privacy are resolved
        resources '200995', only: %i[create show], controller: controller_path do
          collection do
            post 'validate'
            get '/:id/download', action: 'download'
          end
        end
      end

      resources :evidence_submissions,
                only: %i[create show],
                controller: "#{controller_path}/evidence_submissions",
                path: 'evidence-submissions'

      namespace :schemas, controller: controller_path do
        get '200995', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end

  namespace :appealable_issues, path: 'appealable-issues', default: { format: 'json' } do
    appealable_issues_controller_path = '/appeals_api/appealable_issues/v0/appealable_issues'

    namespace :v0 do
      get :appealable_issues,
          to: "#{appealable_issues_controller_path}#index",
          path: 'appealable-issues/:decisionReviewType'

      get :healthcheck, to: '/appeals_api/metadata#healthcheck'
      get :upstream_healthcheck,
          to: '/appeals_api/metadata#appeals_status_upstream_healthcheck',
          path: 'upstream-healthcheck'
      get :docs, to: '/appeals_api/docs/v2/docs#ai'

      namespace :schemas, controller: appealable_issues_controller_path do
        get 'params', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end

  namespace :legacy_appeals, path: 'legacy-appeals', defaults: { format: 'json' } do
    namespace :v0 do
      controller_path = '/appeals_api/legacy_appeals/v0/legacy_appeals'

      get :legacy_appeals,
          to: "#{controller_path}#index",
          path: 'legacy-appeals'
      get :healthcheck, to: '/appeals_api/metadata#healthcheck'
      get :upstream_healthcheck,
          to: '/appeals_api/metadata#appeals_status_upstream_healthcheck',
          path: 'upstream-healthcheck'
      get :docs, to: '/appeals_api/docs/v2/docs#la'

      namespace :schemas, controller: controller_path do
        get 'params', action: :schema
      end

      resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
    end
  end
end
