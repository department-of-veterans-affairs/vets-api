# frozen_string_literal: true
module Github
  class GithubService
    class << self
      include SentryLogging
      extend Memoist

      # TODO : use actual repo
      GITHUB_REPO = 'thebravery/thebravery_project'

      def create_issue(feedback)
        # feedback comes in as a hash
        feedback = feedback.symbolize_keys
        begin
          client.create_issue(
            GITHUB_REPO,
            "Title coming soon... #{rand(1...10000)}",
            feedback[:description]
          )
        rescue => e
          log_exception_to_sentry(e)
        end
      end

      private

      def client
        # TODO : use API key instead of login/password
        # this is a fake test account
        Octokit::Client.new(login: 'thebravery', password: 'Passw0rd!')
      end
      memoize :client
    end
  end
end
