# frozen_string_literal: true

require 'claims_api/cid_mapper'

module ClaimsApi
  class ReportingBase < ClaimsApi::ServiceBase
    def unsuccessful_claims_submissions
      errored_claims.pluck(:cid, :created_at, :id).map do |cid, created_at, id|
        { id:, created_at:, cid: }
      end
    end

    def errored_claims
      ClaimsApi::AutoEstablishedClaim.where(
        'status = ? AND created_at BETWEEN ? AND ? AND cid <> ?',
        'errored', @from, @to, '0oagdm49ygCSJTp8X297'
      ).order(:cid, :status)
    end

    def unsuccessful_va_gov_claims_submissions
      arr = errored_va_gov_claims.pluck(:transaction_id, :id).map do |transaction_id, id|
        { transaction_id:, id: }
      end
      map_transaction_ids(arr) if arr.count > 1
    end

    def errored_va_gov_claims
      ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to,
                                            status: 'errored', cid: '0oagdm49ygCSJTp8X297')
                                     .group(:id)
                                     .order(:transaction_id)
    end

    def with_special_issues(cid: nil)
      claims = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to)
      claims = claims.where(cid:) if cid.present?

      claims.map { |claim| claim[:special_issues].length.positive? ? 1 : 0 }.sum.to_f
    end

    def with_flashes(cid: nil)
      claims = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to)
      claims = claims.where(cid:) if cid.present?

      claims.map { |claim| claim[:flashes].length.positive? ? 1 : 0 }.sum.to_f
    end

    def claims_totals
      @claims_consumers.map do |cid|
        counts = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to, cid:).group(:status).count
        totals = counts.sum { |_k, v| v }.to_f

        percentage_with_flashes = "#{((with_flashes(cid:) / totals) * 100).round(2)}%"
        percentage_with_special_issues = "#{((with_special_issues(cid:) / totals) * 100).round(2)}%"

        if totals.positive?
          consumer_name = ClaimsApi::CidMapper.new(cid:).name
          {
            consumer_name => counts.merge(totals:,
                                          percentage_with_flashes: percentage_with_flashes.to_s,
                                          percentage_with_special_issues: percentage_with_special_issues.to_s)
                                   .deep_symbolize_keys
          }
        end
      end
    end

    def poa_totals
      @poa_consumers&.map do |cid|
        counts = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to, cid:).group(:status).count
        totals = counts.sum { |_k, v| v }

        if totals.positive?
          consumer_name = ClaimsApi::CidMapper.new(cid:).name
          {
            consumer_name => counts.merge(totals:)
                                   .deep_symbolize_keys
          }
        end
      end
    end

    def unsuccessful_poa_submissions
      errored_poas.pluck(:cid, :created_at, :id).map do |cid, created_at, id|
        { id:, created_at:, cid: }
      end
    end

    def errored_poas
      ClaimsApi::PowerOfAttorney.where(
        created_at: @from..@to,
        status: %w[errored]
      ).order(:cid, :status)
    end

    def itf_totals
      @itf_consumers&.map do |cid|
        counts = ClaimsApi::IntentToFile.where(created_at: @from..@to, cid:).group(:status).count
        totals = counts.sum { |_k, v| v }

        if totals.positive?
          consumer_name = ClaimsApi::CidMapper.new(cid:).name
          {
            consumer_name => counts.merge(totals:)
                                   .deep_symbolize_keys
          }
        end
      end
    end

    def ews_totals
      @ews_consumers.map do |cid|
        counts = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to, cid:).group(:status).count
        totals = counts.sum { |_k, v| v }

        if totals.positive?
          consumer_name = ClaimsApi::CidMapper.new(cid:).name
          {
            consumer_name => counts.merge(totals:)
                                   .deep_symbolize_keys
          }
        end
      end
    end

    def unsuccessful_evidence_waiver_submissions
      errored_ews.pluck(:cid, :created_at, :id).map do |cid, created_at, id|
        { id:, created_at:, cid: }
      end
    end

    def errored_ews
      ClaimsApi::EvidenceWaiverSubmission.where(
        created_at: @from..@to,
        status: %w[errored]
      ).order(:cid, :status)
    end

    def map_transaction_ids(array)
      # Dynamically generate unique keys like A, B, C, etc.
      transaction_mapping = {}
      key_sequence = ('A'..'Z').to_a
      key_index = 0

      # Map each unique transaction_id to a new key
      array.each do |item|
        transaction_id = item[:transaction_id]
        unless transaction_mapping.key?(transaction_id)
          transaction_mapping[transaction_id] = key_sequence[key_index]
          key_index += 1
        end
      end

      # Group the array by the new keys
      array.group_by { |item| transaction_mapping[item[:transaction_id]] }
    end

    def call_factories
      make_claims
      make_poas
      make_ews_submissions
      make_poas
    end

    def make_claims
      FactoryBot.create(:auto_established_claim_v2, status: 'errored')
      FactoryBot.create(:auto_established_claim_v2, status: 'errored')

      FactoryBot.create(:auto_established_claim_va_gov, created_at: Time.zone.now)
      FactoryBot.create(:auto_established_claim_va_gov, created_at: Time.zone.now)
      FactoryBot.create(:auto_established_claim_va_gov, :set_transaction_id, created_at: Time.zone.now)
      FactoryBot.create(:auto_established_claim_va_gov, :set_transaction_id, created_at: Time.zone.now)

      FactoryBot.create(:auto_established_claim_v2, status: 'errored')
      FactoryBot.create(:auto_established_claim_v2, status: 'pending')
      FactoryBot.create(:auto_established_claim_without_flashes_or_special_issues)
      FactoryBot.create(:auto_established_claim_without_flashes_or_special_issues)
      FactoryBot.create(:auto_established_claim_with_supporting_documents)
      FactoryBot.create(:auto_established_claim)
    end

    def make_poas
      FactoryBot.create(:power_of_attorney, :errored)
      FactoryBot.create(:power_of_attorney, :errored)
      FactoryBot.create(:power_of_attorney)
      FactoryBot.create(:power_of_attorney)
    end

    def make_ews_submissions
      FactoryBot.create(:claims_api_evidence_waiver_submission, :errored)
      FactoryBot.create(:claims_api_evidence_waiver_submission)
      FactoryBot.create(:claims_api_evidence_waiver_submission, :errored)
      FactoryBot.create(:claims_api_evidence_waiver_submission)
    end

    def make_itfs
      FactoryBot.create(:claims_api_intent_to_file, :itf_errored)
      FactoryBot.create(:claims_api_intent_to_file, :itf_errored)
      FactoryBot.create(:claims_api_intent_to_file)
    end

    def gather_consumers
      @claims_consumers = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to).pluck(:cid).uniq
      @poa_consumers = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to).pluck(:cid).uniq
      @ews_consumers = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to).pluck(:cid).uniq
      @itf_consumers = ClaimsApi::IntentToFile.where(created_at: @from..@to).pluck(:cid).uniq
    end

    def db_clean
      # destroys anything created in the last 24 hours
      ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to).destroy_all
      ClaimsApi::PowerOfAttorney.where(created_at: @from..@to).destroy_all
      ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to).destroy_all
      ClaimsApi::IntentToFile.where(created_at: @from..@to).destroy_all
    end
  end
end
