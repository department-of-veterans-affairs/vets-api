# frozen_string_literal: true

module ClaimsApi
  class ReportHourlyUnsuccessfulSubmissions < ClaimsApi::ServiceBase
    def perform
      return if skip_processing?

      @to = Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%l:%M%p %Z')
      @from = 1.hour.ago.in_time_zone('Eastern Time (US & Canada)').strftime('%l:%M%p %Z')
      @errored_claims = ClaimsApi::AutoEstablishedClaim.where(status: 'errored').pluck(:id).uniq
      @errored_poa = ClaimsApi::PowerOfAttorney.where(status: 'errored').pluck(:id).uniq
      @errored_itf = ClaimsApi::IntentToFile.where(status: 'errored').pluck(:id).uniq
      @errored_ews = ClaimsApi::EvidenceWaiverSubmission.where(status: 'errored').pluck(:id).uniq

      if errored_submissions_exist?
        notify(
          @errored_claims,
          @errored_poa,
          @errored_itf,
          @errored_ews,
          @to,
          @from
        )
      end
    end

    # rubocop:disable Metrics/ParameterLists
    def notify(claims, poa, itf, ews, from, to)
      ClaimsApi::Slack::FailedSubmissionsMessenger.new(
        claims,
        poa,
        itf,
        ews,
        to,
        from
      ).notify!
    end
    # rubocop:enable Metrics/ParameterLists

    private

    def errored_submissions_exist?
      [@errored_claims, @errored_poa, @errored_itf, @errored_ews].any? { |var| var.count.positive? }
    end

    def skip_processing?
      !Rails.env.production?
    end
  end
end
