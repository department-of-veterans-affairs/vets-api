# frozen_string_literal: true

module Banners
  class UpdateAllJob
    include Sidekiq::Job

    STATSD_KEY_PREFIX = 'banners.sidekiq.update_all_banners'

    sidekiq_options retry: 5

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']

      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

      message = "#{job_class} retries exhausted"
      Rails.logger.error(message, { job_id:, error_class:, error_message: })
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

      raise e
    end

    def perform
      return unless enabled?

      Banners.update_all
    rescue Banners::Updater::BannerDataFetchError => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.banner_data_fetch_error")
      Rails.logger.error(
        "Banner data fetch failed",
        { error_message: e.message, error_class: e.class.name }
      )
      raise # Re-raise to trigger Sidekiq retries
    end

    private

    def enabled?
      true #should consider bringing in a flipper heres
    end
  end
end
