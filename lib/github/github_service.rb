# frozen_string_literal: true
module Github
  class GithubService
    class << self
      include SentryLogging
      extend Memoist

      # TODO : use actual repo
      GITHUB_REPO = 'thebravery/thebravery_project'

      def create_issue(feedback)
        # feedback comes in as a hash, convert to model
        feedback = Feedback.new(feedback)

        begin
          client.create_issue(
            GITHUB_REPO,
            issue_title(feedback),
            issue_body(feedback),
            assignee: 'thebravery' # TODO: update to real user
          )
        rescue => e
          log_exception_to_sentry(e)
        end
      end

      private

      def client
        # TODO : use API key instead of login/password
        # this is a fake test account
        Octokit::Client.new(login: 'thebravery', password: 'Passw0rd!!')
      end
      memoize :client

      def issue_title(feedback)
        title = feedback.description[0..40]
        title += ' - Response Requested' unless feedback.owner_email.blank?
        title
      end

      def issue_body(feedback)
        email = feedback.owner_email.blank? ? 'NOT PROVIDED' : feedback.owner_email
        body = feedback.description
        body += "\n\nTarget Page: #{feedback.target_page}"
        body += "\nEmail of Author: #{email}"
        body
      end
    end
  end
end
