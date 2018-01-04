# frozen_string_literal: true
require 'github/github_service'

module Github
  class CreateIssueJob
    include Sidekiq::Worker
    THROTTLE = Sidekiq::Limiter.window('prevent_feedback_spam', 4, :minute).freeze

    # :nocov:
    def perform(feedback)
      THROTTLE.within_limit do
        feedback = Feedback.new(feedback)
        create_response = Github::GithubService.create_issue(feedback)
        FeedbackSubmissionMailer.build(feedback, create_response&.html_url).deliver_now
      end
    end
    # :nocov:
  end
end
