# frozen_string_literal: true
module Github
  class GithubService
    class << self
      include SentryLogging
      extend Memoist

      GITHUB_REPO = 'department-of-veterans-affairs/vets.gov-team'

      def create_issue(feedback)
        client.create_issue(
          GITHUB_REPO,
          issue_title(feedback),
          issue_body(feedback),
          assignee: 'va-bot', labels: 'User Feedback'
        )
      rescue => e
        log_exception_to_sentry(e)
        nil
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
        email = feedback.owner_email.blank? ? 'NOT PROVIDED' : obfuscated_email(feedback.owner_email)
        body = feedback.description
        body += "\n\nTarget Page: #{feedback.target_page}"
        body += "\nEmail of Author: #{email}"
        body
      end

      def obfuscated_email(email)
        return '' if email.nil?
        email[0] + '**********'
      end
    end
  end
end
