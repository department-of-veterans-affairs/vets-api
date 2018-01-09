# frozen_string_literal: true
require 'github/github_service'

module Github
  class CreateIssueJob
    include Sidekiq::Worker

    # Rate limiter is only available in sidekiq-enterprise (which is used
    # in production) & requires a license key. For development, regular sidekiq is used
    THROTTLE =
      if Rails.env.production?
        # :nocov:
        Sidekiq::Limiter.window('prevent_feedback_spam', 4, :minute).freeze
        # :nocov:
      else
        class NoThrottle
          def within_limit
            # :nocov:
            yield
            # :nocov:
          end
        end
        NoThrottle.new
      end

    # :nocov:
    def perform(feedback)
      feedback = Feedback.new(feedback)
      THROTTLE.within_limit do
        create_response = Github::GithubService.create_issue(feedback)
        FeedbackSubmissionMailer.build(feedback, create_response&.html_url, create_response&.number).deliver_now
      end
    end
    # :nocov:
  end
end
