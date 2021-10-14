# frozen_string_literal: true

module GithubAuthentication
  class SidekiqWeb
    # rubocop:disable Lint/NestedMethodDefinition
    # rubocop:disable Metrics/MethodLength
    def self.registered(app)
      app.helpers do
        def warden
          env['warden']
        end

        def github_organization_authenticate!(name)
          unless session[:sidekiq_user].organization_member?(name)
            throw :halt, [401, {}, ["You don't have access to organization #{name}"]]
          end
        end

        def github_team_authenticate!(id)
          throw :halt, [401, {}, ["You don't have access to team #{id}"]] unless session[:sidekiq_user].team_member?(id)
        end
      end

      app.before do
        next if current_path == 'unauthenticated'
        next if current_path == 'auth/github/callback'

        session[:sidekiq_user] ||= warden.user

        if session[:sidekiq_user].blank?
          warden.authenticate!(scope: :sidekiq)
          session[:sidekiq_user] = warden.user
        end
        github_organization_authenticate! Settings.sidekiq.github_organization
        github_team_authenticate! Settings.sidekiq.github_team
      end

      app.get('/unauthenticated') { [403, {}, [warden.message || '']] }

      app.get '/auth/github/callback' do
        if params['error']
          redirect '/unauthenticated'
        else
          warden.authenticate!(scope: :sidekiq)
          redirect root_path
        end
      end
    end
  end
  # rubocop:enable Lint/NestedMethodDefinition
  # rubocop:enable Metrics/MethodLength
end
