# frozen_string_literal: true

module ClaimsApi
  class ReportHourlyUnsuccessfulSubmissions < ClaimsApi::ServiceBase
    sidekiq_options retry: 7

    NO_INVESTIGATION_ERROR_TEXT = [
      'The Maximum number of EP codes have been reached for this benefit type claim code',
      'Claim could not be established. Retries will fail.'
    ].freeze

    # rubocop:disable Metrics/MethodLength
    def perform
      return unless allow_processing?

      @search_to = 1.minute.ago
      @search_from = @search_to - 60.minutes
      @reporting_to = @search_to.in_time_zone('Eastern Time (US & Canada)').strftime('%I:%M%p %Z')
      @reporting_from = @search_from.in_time_zone('Eastern Time (US & Canada)').strftime('%I:%M%p %Z')
      @errored_claims = ClaimsApi::AutoEstablishedClaim.where(
        'status = ? AND created_at BETWEEN ? AND ? AND cid <> ?',
        'errored', @search_from, @search_to, '0oagdm49ygCSJTp8X297'
      ).pluck(:id).uniq
      @va_gov_errored_claims = get_filtered_unique_errors # Array of [id, transaction_id]
      @errored_poa = ClaimsApi::PowerOfAttorney.where(created_at: @search_from..@search_to,
                                                      status: 'errored').pluck(:id).uniq
      @errored_itf = ClaimsApi::IntentToFile.where(created_at: @search_from..@search_to,
                                                   status: 'errored').pluck(:id).uniq
      @errored_ews = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @search_from..@search_to,
                                                               status: 'errored').pluck(:id).uniq
      @environment = Rails.env
      if errored_submissions_exist?
        ClaimsApi::Slack::FailedSubmissionsMessenger.new(
          errored_disability_claims: @errored_claims,
          errored_va_gov_claims: @va_gov_errored_claims,
          errored_poa: @errored_poa,
          errored_itf: @errored_itf,
          errored_ews: @errored_ews,
          from: @reporting_from,
          to: @reporting_to,
          environment: @environment
        ).notify!
      end
    end
    # rubocop:enable Metrics/MethodLength

    private

    def errored_submissions_exist?
      [@errored_claims, @va_gov_errored_claims, @errored_poa, @errored_itf, @errored_ews].any? do |collection|
        collection&.count&.positive?
      end
    end

    def allow_processing?
      Flipper.enabled? :claims_hourly_slack_error_report_enabled
    end

    def get_filtered_unique_errors
      unique_errors = unique_errors_by_transaction_id
      filtered_error_ids = []

      unique_errors.each do |ue|
        filtered_error_ids << [ue[:id], ue[:transaction_id].presence] unless NO_INVESTIGATION_ERROR_TEXT.any? do |text|
          ue[:evss_response].to_s&.include?(text)
        end
      end

      # return signature: [[id, transaction_id],...]
      filtered_error_ids
    end

    def unique_errors_by_transaction_id
      last_day = ClaimsApi::AutoEstablishedClaim
                 .where(created_at: 24.hours.ago..1.hour.ago,
                        status: 'errored', cid: '0oagdm49ygCSJTp8X297')

      last_hour = ClaimsApi::AutoEstablishedClaim
                  .select('DISTINCT ON(transaction_id) *')
                  .where(created_at: 1.hour.ago..Time.zone.now,
                         status: 'errored', cid: '0oagdm49ygCSJTp8X297')

      day_trans_ids = last_day&.pluck(:transaction_id)

      last_hour.find_all do |claim|
        day_trans_ids.exclude?(claim[:transaction_id])
      end
    end
  end
end
