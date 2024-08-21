# frozen_string_literal: true

module ClaimsApi
  class ReportHourlyUnsuccessfulSubmissions < ClaimsApi::ServiceBase
    sidekiq_options retry: 7

    # rubocop:disable Metrics/MethodLength
    def perform
      return unless allow_processing?

      @search_to = 30.minutes.ago
      @search_from = @search_to - 1.hour
      @reporting_to = @search_to.in_time_zone('Eastern Time (US & Canada)').strftime('%l:%M%p %Z')
      @reporting_from = @search_from.in_time_zone('Eastern Time (US & Canada)').strftime('%l:%M%p %Z')
      @errored_claims = ClaimsApi::AutoEstablishedClaim.where(created_at: @search_from..@search_to,
                                                              status: 'errored').pluck(:id).uniq
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
    def notify(claims, poa, itf, ews, from, to, env)
      ClaimsApi::Slack::FailedSubmissionsMessenger.new(
        claims,
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
      [@errored_claims, @errored_poa, @errored_itf, @errored_ews].any? { |var| var.count.positive? }
    end

    def allow_processing?
      Flipper.enabled? :claims_hourly_slack_error_report_enabled
    end
  end
end
