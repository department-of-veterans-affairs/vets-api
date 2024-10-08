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
    [
      { 'consumer 1' => { pending: 2,
                          errored: 1,
                          totals: 3,
                          percentage_with_flashes: '50.0%',
                          percentage_with_special_issues: '50.0%' } },
      { 'consumer 2' => { pending: 3,
                          errored: 3,
                          totals: 6,
                          percentage_with_flashes: '50.0%',
                          percentage_with_special_issues: '50.0%' } }
    ]
    # reporting_base.claims_totals
  end

  def poa_totals
    [
      {
        'consumer 1' => { totals: 10, updated: 5, errored: 2, pending: 1, uploaded: 2 }
      },
      {
        'consumer 2' => { totals: 8, updated: 3, errored: 2, pending: 1, uploaded: 2 }
      }
    ]

    # reporting_base.poa_totals
  end

  def unsuccessful_poa_submissions
    reporting_base.unsuccessful_poa_submissions
  end

  def ews_totals
    [
      {
        'consumer 1' => { totals: 10, updated: 5, errored: 2, pending: 1, uploaded: 2 }
      },
      {
        'consumer 2' => { totals: 8, updated: 3, errored: 2, pending: 1, uploaded: 2 }
      }
    ]
  end

  def unsuccessful_evidence_waiver_submissions
    reporting_base.unsuccessful_evidence_waiver_submissions
  end

  def itf_totals
    # reporting_base.itf_totals
    [
      {
        'consumer 1' => { totals: 2, submitted: 1, errored: 1 }
      },
      {
        'consumer 2' => { totals: 1, submitted: 1, errored: 0 }
      }
    ]
  end

  def reporting_base
    ClaimsApi::ReportingBase.new
  end
end
