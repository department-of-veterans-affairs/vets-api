# frozen_string_literal: true

module GithubAuthentication
  class SidekiqWeb
    # rubocop:disable Lint/NestedMethodDefinition
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
      end

      app.before do
        next if current_path == 'unauthenticated'

        warden.authenticate!
        github_organization_authenticate! 'department-of-veterans-affairs'
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
end