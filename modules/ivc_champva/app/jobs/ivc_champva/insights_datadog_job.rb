# frozen_string_literal: true

require 'sidekiq'

# This job collects IVC CHAMPVA form insights data and publishes metrics to DataDog
# for dashboard visualization. It runs periodically to provide up-to-date insights
# on submission patterns, resubmission rates, and timing analytics.
module IvcChampva
  class InsightsDatadogJob
    include Sidekiq::Job
    sidekiq_options retry: 3

    STATSD_PREFIX = 'ivc_champva.insights'
    DEFAULT_DAYS_AGO = 30
    DEFAULT_GATE = 2

    def perform(days_ago: DEFAULT_DAYS_AGO, gate: DEFAULT_GATE, form_number: '10-10D')
      return unless Flipper.enabled?(:champva_insights_datadog_job)

      insights_service = IvcChampva::ProdSupportUtilities::Insights.new
      metrics = insights_service.gather_submission_metrics(days_ago, gate, form_number)

      publish_basic_metrics(metrics, form_number)
      publish_frequency_metrics(metrics, form_number)
      publish_timing_metrics(metrics, form_number)

      Rails.logger.info(
        "InsightsDatadogJob completed for #{form_number} - #{metrics[:unique_individuals]} users analyzed"
      )
    rescue => e
      Rails.logger.error("InsightsDatadogJob failed: #{e.message}")
      StatsD.increment("#{STATSD_PREFIX}.job_failure", tags: ["form_number:#{form_number}"])
      raise
    end

    private

    def publish_basic_metrics(metrics, form_number)
      tags = ["form_number:#{form_number}", "days_ago:#{metrics[:days_ago]}", "gate:#{metrics[:gate]}"]

      # Core submission statistics
      StatsD.gauge("#{STATSD_PREFIX}.unique_individuals", metrics[:unique_individuals], tags:)
      StatsD.gauge("#{STATSD_PREFIX}.multi_submitters", metrics[:emails_with_multi_submits], tags:)
      StatsD.gauge("#{STATSD_PREFIX}.multi_submission_percentage", metrics[:percentage], tags:)

      # Log key metrics for monitoring
      Rails.logger.info("Insights metrics for #{form_number}: #{metrics[:unique_individuals]} unique users, " \
                        "#{metrics[:emails_with_multi_submits]} multi-submitters (#{metrics[:percentage]}%)")
    end

    def publish_frequency_metrics(metrics, form_number)
      base_tags = ["form_number:#{form_number}"]

      # Publish frequency distribution - number of users for each submission count
      metrics[:frequency_data].each do |submission_count, user_count|
        tags = base_tags + ["submission_count:#{submission_count}"]
        StatsD.gauge("#{STATSD_PREFIX}.frequency.users_with_submissions", user_count, tags:)
      end
    end

    def publish_timing_metrics(metrics, form_number)
      base_tags = ["form_number:#{form_number}"]

      # Publish average time between resubmissions for each submission count
      metrics[:average_time_data].each do |timing_data|
        next if timing_data[:avg_time_seconds].nil?

        submission_count = timing_data[:num_submissions]
        avg_seconds = timing_data[:avg_time_seconds]

        tags = base_tags + ["submission_count:#{submission_count}"]

        # Send average time in seconds for flexibility in dashboard creation
        StatsD.gauge("#{STATSD_PREFIX}.timing.avg_seconds_between_resubmissions", avg_seconds, tags:)

        # Also send in hours for easier dashboard reading
        avg_hours = (avg_seconds / 3600.0).round(2)
        StatsD.gauge("#{STATSD_PREFIX}.timing.avg_hours_between_resubmissions", avg_hours, tags:)
      end
    end
  end
end
