# frozen_string_literal: true

module ClaimsApi
  class ReportHourlyUnsuccessfulSubmissions < ClaimsApi::ServiceBase
    sidekiq_options retry: 7

    # rubocop:disable Metrics/MethodLength
    def perform
      return unless allow_processing?

      @search_to = Time.zone.now
      @search_from = 1.hour.ago
      @reporting_to = Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%l:%M%p %Z')
      @reporting_from = 1.hour.ago.in_time_zone('Eastern Time (US & Canada)').strftime('%l:%M%p %Z')
      @errored_claims = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to, status: 'errored').pluck(:id).uniq
      @errored_poa = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to, status: 'errored').pluck(:id).uniq
      @errored_itf = ClaimsApi::IntentToFile.where(created_at: @from..@to, status: 'errored').pluck(:id).uniq
      @errored_ews = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to,
                                                               status: 'errored').pluck(:id).uniq
      @environment = Rails.env

      if errored_submissions_exist?
        notify(
          @errored_claims,
          @errored_poa,
          @errored_itf,
          @errored_ews,
          @reporting_to,
          @reporting_from,
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
        to,
        from,
        env
      ).notify!
    end
    # rubocop:enable Metrics/ParameterLists

    private

    def errored_submissions_exist?
      [@errored_claims, @errored_poa, @errored_itf, @errored_ews].any? { |var| var.count.positive? }
    end

    def allow_processing?
      Settings.claims_api.hourly_failed_submission_reports_enabled || false
    end
  end
end
