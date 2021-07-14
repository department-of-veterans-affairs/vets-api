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
          unless warden.user.organization_member?(name)
            throw :halt, [401, {}, ["You don't have access to organization #{name}"]]
          end
        end

        def github_team_authenticate!(id)
          throw :halt, [401, {}, ["You don't have access to team #{id}"]] unless warden.user.team_member?(id)
        end
      end

      app.before do
        next if current_path == 'unauthenticated'
        next if current_path == 'auth/github/callback'

        unless session[:user]
          warden.authenticate!
          github_organization_authenticate! Settings.sidekiq.github_organization
          github_team_authenticate! Settings.sidekiq.github_team
          session[:user] = warden.user
        end
      end

      app.get('/unauthenticated') { [403, {}, [warden.message || '']] }

      app.get '/auth/github/callback' do
        if params['error']
          redirect '/unauthenticated'
        else
          warden.authenticate!
          redirect root_path
        end
      end
    end
  end
  # rubocop:enable Lint/NestedMethodDefinition
  # rubocop:enable Metrics/MethodLength
end
