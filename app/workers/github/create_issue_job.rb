# frozen_string_literal: true
require 'github/github_service'

module Github
  class CreateIssueJob
    include Sidekiq::Worker

    # Rate limiter is only available in sidekiq-enterprise (which is used
    # in production) & requires a license key. For development, regular sidekiq is used
    # :nocov:
    THROTTLE =
      if Rails.env.production?
        Sidekiq::Limiter.window('prevent_feedback_spam', 4, :minute).freeze
      else
        class NoThrottle
          def within_limit
            yield
          end
        end
        NoThrottle.new
      end

    def perform(feedback)
      feedback = Feedback.new(feedback)
      THROTTLE.within_limit do
        create_response = Github::GithubService.create_issue(feedback)
        FeedbackSubmissionMailer.build(feedback, create_response&.html_url).deliver_now
      end
    end
    # :nocov:
  end
end
