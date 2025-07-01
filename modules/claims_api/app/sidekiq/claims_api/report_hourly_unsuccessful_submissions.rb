# frozen_string_literal: true

module ClaimsApi
  class ReportHourlyUnsuccessfulSubmissions < ClaimsApi::ServiceBase
    sidekiq_options retry: 7

    NO_INVESTIGATION_ERROR_TEXT = [
      'The Maximum number of EP codes have been reached for this benefit type claim code',
      'Claim could not be established. Retries will fail.'
    ].freeze

    VAGOV_CID = '0oagdm49ygCSJTp8X297'

    # rubocop:disable Metrics/MethodLength
    def perform
      return unless allow_processing?

      @search_to = 1.minute.ago
      @search_from = @search_to - 60.minutes
      @reporting_to = @search_to.in_time_zone('Eastern Time (US & Canada)').strftime('%I:%M%p %Z')
      @reporting_from = @search_from.in_time_zone('Eastern Time (US & Canada)').strftime('%I:%M%p %Z')
      @unresolved_claims = find_unresolved_errored_claims
      @errored_poa = ClaimsApi::PowerOfAttorney.where(created_at: @search_from..@search_to,
                                                      status: 'errored').pluck(:id).uniq
      @errored_itf = ClaimsApi::IntentToFile.where(created_at: @search_from..@search_to,
                                                   status: 'errored').pluck(:id).uniq
      @errored_ews = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @search_from..@search_to,
                                                               status: 'errored').pluck(:id).uniq
      @environment = Rails.env
      if errored_submissions_exist?
        ClaimsApi::Slack::FailedSubmissionsMessenger.new(
          unresolved_errored_claims: @unresolved_claims,
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
      [@unresolved_claims, @errored_poa, @errored_itf, @errored_ews].any? do |collection|
        collection&.count&.positive?
      end
    end

    def allow_processing?
      Flipper.enabled? :claims_hourly_slack_error_report_enabled
    end

    def transaction_id_extracted(transaction_id)
      transaction_id&.split(',')&.first&.scan(/[a-zA-Z0-9_-]+/)&.first&.downcase
    end

    def find_unresolved_errored_claims
      errored_claims = fetch_errored_claims_in_window
      return [] if errored_claims.empty?

      errored_transaction_ids = extract_transaction_ids_from_claims(errored_claims)
      return [] if errored_transaction_ids.empty?

      resolved_transaction_ids = find_resolved_transaction_ids(errored_transaction_ids)
      unresolved_transaction_ids = errored_transaction_ids - resolved_transaction_ids

      build_unresolved_claim_context(unresolved_transaction_ids, errored_claims)
    end

    def fetch_errored_claims_in_window
      ClaimsApi::AutoEstablishedClaim.where(status: 'errored', created_at: @search_from..@search_to)
    end

    def extract_transaction_ids_from_claims(claims)
      claims.map { |c| transaction_id_extracted(c.transaction_id) }.compact.uniq
    end

    def find_resolved_transaction_ids(errored_ids)
      conditions_sql = errored_ids.map { 'LOWER(transaction_id) LIKE ?' }.join(' OR ')
      condition_values = errored_ids.map { |id| "#{id.downcase}%" }

      resolved_claims = ClaimsApi::AutoEstablishedClaim
                        .where(status: 'established')
                        .where(conditions_sql, *condition_values)
                        .pluck(:transaction_id)

      resolved_claims.map { |id| transaction_id_extracted(id) }.compact.uniq
    end

    def build_unresolved_claim_context(unresolved_ids, errored_claims)
      unresolved_ids.map do |transaction_id|
        claim = errored_claims.find { |c| transaction_id_extracted(c.transaction_id) == transaction_id }
        next if claim.nil?

        {
          transaction_id:,
          is_va_gov: claim.cid == VAGOV_CID
        }
      end.compact
    end
  end
end
