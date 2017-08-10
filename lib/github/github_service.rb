# frozen_string_literal: true
module Github
  class GithubService
    class << self
      include SentryLogging
      extend Memoist

      GITHUB_REPO = 'department-of-veterans-affairs/vets.gov-team'

      def create_issue(feedback)
        feedback = Feedback.new(feedback)

        begin
          client.create_issue(
            GITHUB_REPO,
            issue_title(feedback),
            issue_body(feedback),
            assignee: 'omgitsbillryan' # TODO: assign to someone... not me!
          )
        rescue => e
          log_exception_to_sentry(e)
        end
      end

      private

      def client
        Octokit::Client.new(access_token: Settings.github.api_key)
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
