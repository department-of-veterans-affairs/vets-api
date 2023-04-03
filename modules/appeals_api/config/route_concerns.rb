# frozen_string_literal: true

# Routes in this file are used in two places:
# * Deprecated routes (/services/appeals/<api_name>/v0/*):
#   These are old routes, which use underscores and thus don't comply with Lighthouse API standards
# * Current routes (/services/appeals/<api-name>/v0/*):
#   These are revised routes that comply with Lighthouse API standards by using hyphens and being mounted at /services
# FIXME: Once no systems outside of vets-api rely on the deprecated routes, we can remove them
# This file can also be removed and the current routes reconfigured as usual in routes.rb

def segment(str, deprecated)
  deprecated ? str.gsub('-', '_') : str
end

module AppealsApi
  class SharedRoutes
    NoticeOfDisagreements = proc do |mapper, opts|
      controller_path = '/appeals_api/notice_of_disagreements/v0/notice_of_disagreements'
      deprecated = opts[:deprecated]

      mapper.instance_eval do
        namespace :notice_of_disagreements,
                  path: segment('notice-of-disagreements', deprecated),
                  defaults: { format: 'json' } do
          namespace :v0 do
            get :healthcheck, to: '/appeals_api/metadata#healthcheck'
            get :upstream_healthcheck,
                to: '/appeals_api/metadata#mail_status_upstream_healthcheck',
                path: segment('upstream-healthcheck', deprecated)
            get :docs, to: '/appeals_api/docs/v2/docs#nod' unless deprecated

            namespace :forms do
              resources '10182', only: %i[create show], controller: controller_path do
                collection do
                  post 'validate'
                end
              end
            end

            resources :evidence_submissions,
                      only: %i[create show],
                      controller: "#{controller_path}/evidence_submissions",
                      path: segment('evidence-submissions', deprecated)

            namespace :schemas, controller: controller_path do
              get '10182', action: :schema
            end

            resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
          end
        end
      end
    end

    HigherLevelReviews = proc do |mapper, opts|
      controller_path = '/appeals_api/higher_level_reviews/v0/higher_level_reviews'
      deprecated = opts[:deprecated]

      mapper.instance_eval do
        namespace :higher_level_reviews,
                  path: segment('higher-level-reviews', deprecated),
                  defaults: { format: 'json' } do
          namespace :v0 do
            get :healthcheck, to: '/appeals_api/metadata#healthcheck'
            get :upstream_healthcheck,
                to: '/appeals_api/metadata#mail_status_upstream_healthcheck',
                path: segment('upstream-healthcheck', deprecated)
            get :docs, to: '/appeals_api/docs/v2/docs#hlr' unless deprecated

            namespace :forms do
              resources '200996', only: %i[create show], controller: controller_path do
                collection do
                  post 'validate'
                end
              end
            end

            namespace :schemas, controller: controller_path do
              get '200996', action: :schema
            end

            resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
          end
        end
      end
    end

    SupplementalClaims = proc do |mapper, opts|
      controller_path = '/appeals_api/supplemental_claims/v0/supplemental_claims'
      deprecated = opts[:deprecated]

      mapper.instance_eval do
        namespace :supplemental_claims,
                  path: segment('supplemental-claims', deprecated),
                  defaults: { format: 'json' } do
          namespace :v0 do
            get :healthcheck, to: '/appeals_api/metadata#healthcheck'
            get :upstream_healthcheck,
                to: '/appeals_api/metadata#mail_status_upstream_healthcheck',
                path: segment('upstream-healthcheck', deprecated)
            get :docs, to: '/appeals_api/docs/v2/docs#sc' unless deprecated

            namespace :forms do
              resources '200995', only: %i[create show], controller: controller_path do
                collection do
                  post 'validate'
                end
              end
            end

            resources :evidence_submissions,
                      only: %i[create show],
                      controller: "#{controller_path}/evidence_submissions",
                      path: segment('evidence-submissions', deprecated)

            namespace :schemas, controller: controller_path do
              get '200995', action: :schema
            end

            resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
          end
        end
      end
    end

    ContestableIssues = proc do |mapper, opts|
      controller_path = '/appeals_api/contestable_issues/v0/contestable_issues'
      deprecated = opts[:deprecated]

      mapper.instance_eval do
        namespace :contestable_issues, path: segment('contestable-issues', deprecated), defaults: { format: 'json' } do
          namespace :v0 do
            get :contestable_issues,
                to: "#{controller_path}#index",
                path: "#{segment('contestable-issues', deprecated)}/:decision_review_type"
            get :healthcheck, to: '/appeals_api/metadata#healthcheck'
            get :upstream_healthcheck,
                to: '/appeals_api/metadata#appeals_status_upstream_healthcheck',
                path: segment('upstream-healthcheck', deprecated)
            get :docs, to: '/appeals_api/docs/v2/docs#ci' unless deprecated

            namespace :schemas, controller: controller_path do
              get 'headers', action: :schema
            end

            resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
          end
        end
      end
    end

    LegacyAppeals = proc do |mapper, opts|
      controller_path = '/appeals_api/legacy_appeals/v0/legacy_appeals'
      deprecated = opts[:deprecated]

      mapper.instance_eval do
        namespace :legacy_appeals, path: segment('legacy-appeals', deprecated), defaults: { format: 'json' } do
          namespace :v0 do
            get :legacy_appeals,
                to: "#{controller_path}#index",
                path: segment('legacy-appeals', deprecated)
            get :healthcheck, to: '/appeals_api/metadata#healthcheck'
            get :upstream_healthcheck,
                to: '/appeals_api/metadata#appeals_status_upstream_healthcheck',
                path: segment('upstream-healthcheck', deprecated)
            get :docs, to: '/appeals_api/docs/v2/docs#la' unless deprecated

            namespace :schemas, controller: controller_path do
              get 'headers', action: :schema
            end

            resources :schemas, only: :show, param: :schema_type, controller: '/appeals_api/schemas/shared_schemas'
          end
        end
      end
    end

    # NOTE: appeals status was not part of decision reviews, so the route differences here are different from those
    # between the other APIs' routes
    AppealsStatus = proc do |mapper, opts|
      controller_action = '/appeals_api/v1/appeals#index'
      healthcheck_action = '/appeals_api/metadata#healthcheck'
      upstream_healthcheck_action = '/appeals_api/metadata#appeals_status_upstream_healthcheck'
      deprecated = opts[:deprecated]

      mapper.instance_eval do
        if deprecated
          namespace :v1, defaults: { format: 'json' } do
            get :appeals, to: controller_action
            get :appeals_healthcheck, to: healthcheck_action
            get :appeals_upstream_healthcheck, to: upstream_healthcheck_action
          end
        else
          namespace :appeals_status, path: 'appeals-status', defaults: { format: 'json' } do
            namespace :v1, defaults: { format: 'json' } do
              get :appeals, to: controller_action
              get :healthcheck, to: healthcheck_action
              get :upstream_healthcheck, to: upstream_healthcheck_action, path: 'upstream-healthcheck'
              get :docs, to: '/appeals_api/docs/v1/docs#appeals_status' unless deprecated
            end
          end
        end
      end
    end
  end
end
