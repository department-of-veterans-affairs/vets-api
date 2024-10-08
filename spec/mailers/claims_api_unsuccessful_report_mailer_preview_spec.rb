# frozen_string_literal: true

require 'rails_helper'
require 'modules/claims_api/app/sidekiq/claims_api/reporting_base'
require_relative 'previews/claims_api_unsuccessful_report_mailer_preview'

RSpec.describe ClaimsApiUnsuccessfulReportMailerPreview, type: [:mailer] do
  let(:to) { Time.zone.now }
  let(:from) { 1.day.ago }

    let(:consumer_claims_totals) { reporting_base.claims_totals }
    let(:unsuccessful_claims_submissions) { reporting_base.unsuccessful_claims_submissions }
    let(:unsuccessful_va_gov_claims_submissions) { reporting_base.unsuccessful_va_gov_claims_submissions }
    let(:poa_totals) { reporting_base.poa_totals }
    let(:unsuccessful_poa_submissions) { reporting_base.unsuccessful_poa_submissions }
    let(:ews_totals) { reporting_base.ews_totals }
    let(:unsuccessful_evidence_waiver_submissions) { reporting_base.unsuccessful_evidence_waiver_submissions }
    let(:itf_totals) { reporting_base.itf_totals }

  describe "" do
    it "" do
      db_clean
      call_factories
      gather_consumers
      described_class.new.build(
        consumer_claims_totals:,
        unsuccessful_claims_submissions:,
        unsuccessful_va_gov_claims_submissions:,
        poa_totals:,
        unsuccessful_poa_submissions:,
        ews_totals:,
        unsuccessful_evidence_waiver_submissions:,
        itf_totals:
      ).deliver_now
debugger
      expect(subject).to eq(true)
    end
  end

  private

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
    FactoryBot.create(:auto_established_claim_va_gov, :transaction_id_25, created_at: Time.zone.now)
    FactoryBot.create(:auto_established_claim_va_gov, :transaction_id_25, created_at: Time.zone.now)

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
