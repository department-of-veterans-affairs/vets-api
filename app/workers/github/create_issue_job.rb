# frozen_string_literal: true

require 'github/github_service'
require 'sidekiq/instrument/mixin'

module Github
  class CreateIssueJob
    include Sidekiq::Instrument::MetricNames
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
        # create_response = Github::GithubService.create_issue(feedback)
        FeedbackSubmissionMailer.build(
          feedback,
          'Automatic Github issue creation skipped.',
          Time.now.to_f
        ).deliver_now
      end
    rescue Exception => e
      StatsD.increment(metric_name(self, 'rate_limited')) if e.class.name == 'Sidekiq::Limiter::OverLimit'
      raise e
    end
    # :nocov:
  end
end
