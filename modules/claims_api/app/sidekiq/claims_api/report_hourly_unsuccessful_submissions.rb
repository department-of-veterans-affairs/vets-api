# frozen_string_literal: true

module ClaimsApi
  class ReportHourlyUnsuccessfulSubmissions < ClaimsApi::ServiceBase
    sidekiq_options retry: 7

    # rubocop:disable Metrics/MethodLength
    def perform
      return unless allow_processing?

      @search_to = Time.zone.now
      @search_from = @search_to - 60.minutes
      @reporting_to = @search_to.in_time_zone('Eastern Time (US & Canada)').strftime('%l:%M%p %Z')
      @reporting_from = @search_from.in_time_zone('Eastern Time (US & Canada)').strftime('%l:%M%p %Z')
      @errored_claims = ClaimsApi::AutoEstablishedClaim.where(
        'status = ? AND created_at BETWEEN ? AND ? AND cid <> ?',
        'errored', @search_from, @search_to, '0oagdm49ygCSJTp8X297'
      ).pluck(:id).uniq
      @va_gov_errored_claims = va_gov_errored_claims.map { |grp| grp[1][0] }.pluck(:id)
      @errored_poa = ClaimsApi::PowerOfAttorney.where(created_at: @search_from..@search_to,
                                                      status: 'errored').pluck(:id).uniq
      @errored_itf = ClaimsApi::IntentToFile.where(created_at: @search_from..@search_to,
                                                   status: 'errored').pluck(:id).uniq
      @errored_ews = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @search_from..@search_to,
                                                               status: 'errored').pluck(:id).uniq
      @environment = Rails.env

      if errored_submissions_exist?
        notify(
          @errored_claims,
          @va_gov_errored_claims,
          @errored_poa,
          @errored_itf,
          @errored_ews,
          @reporting_from,
          @reporting_to,
          @environment
        )
      end
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/ParameterLists
    def notify(claims, va_claims, poa, itf, ews, from, to, env)
      ClaimsApi::Slack::FailedSubmissionsMessenger.new(
        claims,
        va_claims,
        poa,
        itf,
        ews,
        from,
        to,
        env
      ).notify!
    end
    # rubocop:enable Metrics/ParameterLists

    private

    def errored_submissions_exist?
      [@errored_claims, @va_gov_errored_claims, @errored_poa, @errored_itf, @errored_ews].any? do |var|
        var.count.positive?
      end
    end

    def allow_processing?
      Flipper.enabled? :claims_hourly_slack_error_report_enabled
    end

    def va_gov_errored_claims
      errored_claims = get_unique_errors
      errored_claims.group_by(&:transaction_id)
    end

    def get_unique_errors
      starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      two_days = ClaimsApi::AutoEstablishedClaim.where(created_at: 48.hours.ago..@search_to,
                                                       status: 'errored', cid: '0oagdm49ygCSJTp8X297')

      unique = two_days.uniq { |claim| claim[:transaction_id] }
      errored_claims = unique.select { |claim| claim[:created_at] >= @search_from }
      # Elapsd time: 0.01658499985933304 seconds
      
      ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed = ending - starting
      ClaimsApi::Logger.log('hourly_slack_alert_elapsed_time', detail: "Elapsd time: #{elapsed} seconds")
      
      errored_claims
    end
  end
end

# last_modified = ClaimsApi::AutoEstablishedClaim.order(:updated_at).last
# last_modified_str = last_modified.updated_at.utc.to_s
# cache_key = "all_errors/#{last_modified_str}"

# errored_claims = []
# @alert_groups ||= ClaimsApi::AutoEstablishedClaim.where(created_at: 48.hour.ago..Time.zone.now,
# status: 'errored', cid: '0oagdm49ygCSJTp8X297')

# all_errors = Rails.cache.fetch(cache_key) do
#   @alert_groups
# end
# unique = all_errors.uniq { |claim| claim[:transaction_id] }
# errored_claims = unique.select { |claim| claim[:created_at] >= @search_from }
# Elapsd time: 0.0341619998216629 seconds