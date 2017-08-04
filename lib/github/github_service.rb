# frozen_string_literal: true
module Github
  class GithubService
    class << self
      include SentryLogging
      extend Memoist

      # TODO : use actual repo
      GITHUB_REPO = 'thebravery/thebravery_project'

      def create_issue(title:, description:)
        begin
          client.create_issue(GITHUB_REPO, title, description)
        rescue Exception => e
          log_exception_to_sentry(e)
        end
      end

      private

      def client
        # TODO : use API key instead of login/password
        Octokit::Client.new(:login => 'thebravery', :password => 'Passw0rd!')
      end
      memoize :client
    end
  end
end