# frozen_string_literal: true
module Github
  class GithubService
    class << self
      include SentryLogging
      extend Memoist

      # source: https://stackoverflow.com/a/27194235
      EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i

      # source https://stackoverflow.com/a/20386405
      SSN_REGEX = /(\d{3})[^\d]?\d{2}[^\d]?\d{4}/

      GITHUB_REPO = 'department-of-veterans-affairs/vets.gov-team'

      def create_issue(feedback)
        # in case user provides PII in feedback description
        feedback.description = sanitize(feedback.description, EMAIL_REGEX)
        feedback.description = sanitize(feedback.description, SSN_REGEX)

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

      def sanitize(str, regex)
        matched = str.match(regex)
        return str unless matched
        str.gsub(matched.to_s, matched.to_s[0] + '**********')
      end
    end
  end
end
