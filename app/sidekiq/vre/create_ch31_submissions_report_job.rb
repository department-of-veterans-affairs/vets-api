# frozen_string_literal: true

module VRE
  class CreateCh31SubmissionsReportJob
    require 'csv'
    include Sidekiq::Job
    include SentryLogging

    STATSD_KEY_PREFIX = 'worker.vre.create_ch31_submissions_report_job'

    # Sidekiq has built in exponential back-off functionality for retries
    # A max retry attempt of 14 will result in a run time of ~25 hours
    RETRY = 14

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      Rails.logger.error(
        "Failed all retries on VRE::CreateCh31SubmissionsReportJob, last error: #{msg['error_message']}"
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
    end

    def perform(sidekiq_scheduler_args, run_date = nil)
      date = if run_date
               run_date
             else
               epoch = sidekiq_scheduler_args['scheduled_at']
               Time.zone.at(epoch).yesterday.strftime('%Y-%m-%d')
             end

      submitted_claims = get_claims_created_between(build_range(date))
      Ch31SubmissionsReportMailer.build(submitted_claims).deliver_now unless FeatureFlipper.staging_email?
    rescue => e
      log_message_to_sentry(
        'VRE::CreateCh31SubmissionsReportJob failed, retrying...', :warn, generate_sentry_details(e)
      )
      raise
    end

    private

    def build_range(report_date)
      zone = 'Eastern Time (US & Canada)'
      begin_time = ActiveSupport::TimeZone[zone].parse("#{report_date} 00:00:00")
      end_time = ActiveSupport::TimeZone[zone].parse("#{report_date} 23:59:59")
      begin_time..end_time
    end

    def get_claims_created_between(range)
      SavedClaim::VeteranReadinessEmploymentClaim.where(
        created_at: range
      ).sort_by { |claim| claim.parsed_form['veteranInformation']['regionalOffice'] }
    end
  end
end
