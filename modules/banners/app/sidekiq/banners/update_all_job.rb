# frozen_string_literal: true

module Banners
  class UpdateAllJob
    include Sidekiq::Job

    STATSD_KEY_PREFIX = 'banners.sidekiq.update_all_banners'

    sidekiq_options retry: 3

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']

      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

      message = "#{job_class} retries exhausted"
      Rails.logger.error(message, { job_id:, error_class:, error_message: })
    rescue => e
      Rails.logger.error(
        "Failure in #{job_class}#sidekiq_retries_exhausted",
        {
          messaged_content: e.message,
          job_id:,
          pre_exhaustion_failure: {
            error_class:,
            error_message:
          }
        }
      )

      raise e
    end

    def perform
      return unless enabled?

      Banners.update_all
    rescue Banners::Updater::BannerDataFetchError => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.banner_data_fetch_error")
      Rails.logger.warn(
        'Banner data fetch failed',
        { error_message: e.message, error_class: e.class.name }
      )

      # Job has failed, this is likely due to a communication error with the Drupal API.
      # In this case, we don't want to retry this job as it will be scheduled via periodic_jobs.rb within 5 minutes
      # We return false to mark it as failed without retrying.
      false
    end

    private

    def enabled?
      Flipper.enabled?(:banner_update_alternative_banners)
    end
  end
end
