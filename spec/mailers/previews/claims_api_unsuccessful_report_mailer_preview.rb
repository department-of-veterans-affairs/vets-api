# frozen_string_literal: true

require './modules/claims_api/app/sidekiq/claims_api/reporting_base'

class ClaimsApiUnsuccessfulReportMailerPreview < ActionMailer::Preview
  def build
    to = Time.zone.now
    from = 1.day.ago

    ClaimsApi::UnsuccessfulReportMailer.build(
      from,
      to,
      consumer_claims_totals: claims_totals,
      unsuccessful_claims_submissions:,
      unsuccessful_va_gov_claims_submissions:,
      poa_totals:,
      unsuccessful_poa_submissions:,
      ews_totals:,
      unsuccessful_evidence_waiver_submissions:,
      itf_totals:
    )
  end

  private

  def unsuccessful_claims_submissions
    reporting_base.unsuccessful_claims_submissions
  end

  def unsuccessful_va_gov_claims_submissions
    reporting_base.unsuccessful_va_gov_claims_submissions
  end

  def claims_totals
    call_factories

    reporting_base.claims_totals
  end

  def poa_totals
    reporting_base.poa_totals
  end

  def unsuccessful_poa_submissions
    reporting_base.unsuccessful_poa_submissions
  end

  def ews_totals
    reporting_base.ews_totals
  end

  def unsuccessful_evidence_waiver_submissions
    reporting_base.unsuccessful_evidence_waiver_submissions
  end

  def itf_totals
    reporting_base.itf_totals
  end

  def reporting_base
    ClaimsApi::ReportingBase.new
  end

  def call_factories
    make_claims
    make_poas
    make_ews_submissions
    make_itfs
    gather_consumers
  end

  def make_claims
    FactoryBot.build(:auto_established_claim_v2, :errored)
    FactoryBot.build(:auto_established_claim, :errored)

    FactoryBot.build(:auto_established_claim_va_gov, created_at: Time.zone.now)
    FactoryBot.build(:auto_established_claim_va_gov, created_at: Time.zone.now)
    FactoryBot.build(:auto_established_claim_va_gov, created_at: Time.zone.now)
    FactoryBot.build(:auto_established_claim_va_gov, created_at: Time.zone.now)

    FactoryBot.build(:auto_established_claim_v2, :errored)
    FactoryBot.build(:auto_established_claim_v2, :pending)
    FactoryBot.build(:auto_established_claim_without_flashes_or_special_issues)
    FactoryBot.build(:auto_established_claim_without_flashes_or_special_issues)
    FactoryBot.build(:auto_established_claim_with_supporting_documents)
    FactoryBot.build(:auto_established_claim)
  end

  def make_poas
    FactoryBot.build(:power_of_attorney, :errored)
    FactoryBot.build(:power_of_attorney, :errored)
    FactoryBot.build(:power_of_attorney)
    FactoryBot.build(:power_of_attorney)
  end

  def make_ews_submissions
    FactoryBot.build(:claims_api_evidence_waiver_submission, :errored)
    FactoryBot.build(:claims_api_evidence_waiver_submission)
    FactoryBot.build(:claims_api_evidence_waiver_submission, :errored)
    FactoryBot.build(:claims_api_evidence_waiver_submission)
  end

  def make_itfs
    FactoryBot.build(:intent_to_file, :itf_errored)
    FactoryBot.build(:intent_to_file, :itf_errored)
    FactoryBot.build(:intent_to_file)
  end

  def gather_consumers
    @claims_consumers = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to).pluck(:cid).uniq
    @poa_consumers = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to).pluck(:cid).uniq
    @ews_consumers = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to).pluck(:cid).uniq
    @itf_consumers = ClaimsApi::IntentToFile.where(created_at: @from..@to).pluck(:cid).uniq
  end
end
