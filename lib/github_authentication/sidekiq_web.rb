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
            halt [401, {}, ["You don't have access to organization #{name}"]]
          end
        end

        def github_team_authenticate!(id)
          halt [401, {}, ["You don't have access to team #{id}"]] unless warden.user.team_member?(id)
        end
      end

      app.before do
        next if current_path == 'unauthenticated'

        unless warden.authenticated? || session[:user]
          warden.authenticate!
          session[:user] = warden.user
          github_organization_authenticate! Settings.sidekiq.github_organization
          github_team_authenticate! Settings.sidekiq.github_team
        end
      end

      app.get('/unauthenticated') { [403, {}, [warden.message || '']] }

      app.get '/auth/github/callback' do
        if params['error']
          redirect '/unauthenticated'
        else
          warden.authenticate!
          session[:user] = warden.user
          redirect root_path
        end
      end
    end
  end
  # rubocop:enable Lint/NestedMethodDefinition
  # rubocop:enable Metrics/MethodLength
end
