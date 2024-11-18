# frozen_string_literal: true

require 'sidekiq'

# TODO: Simlify this job, move the logic for fetching and updating banners into a lib/service module
#       and have this Banner Job just call that service module
module Banners
  class PullAndUpdateDb
    include Sidekiq::Job

    sidekiq_options retry: 7

    STATSD_KEY_PREFIX = 'api.banners.pull_and_update_db'

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']

      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

      message = "#{job_class} retries exhausted"
      Rails.logger.error(message, { job_id:, error_class:, error_message: })
      # TODO: Consider adding Slack notification (or DD monitor that captures these errors for slack announcing)
    rescue => e
      message = "Failure in #{job_class}#sidekiq_retries_exhausted"
      Rails.logger.error(
        message,
        {
          messaged_content: e.message,
          job_id:,
          pre_exhaustion_failure: {
            error_class:,
            error_message:
          }
        }
      )
      # TODO: Consider adding Slack notification (or DD monitor that captures these errors for slack announcing)

      raise e
    end

    def perform
      Banners.update_all
    end
  end
end
