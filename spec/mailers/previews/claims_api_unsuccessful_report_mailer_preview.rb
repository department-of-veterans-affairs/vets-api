# frozen_string_literal: true

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
    [
      { id: '019be853-fd70-4b65-b37b-c3f3842aaaca', status: 'errored', source: 'GDIT', created_at: 1.day.ago.to_s }
    ]
  end

  def unsuccessful_va_gov_claims_submissions
    {
      A: [ { transaction_id: '13259605526122682833', id: '82664de8-b3de-4e6f-aec1-8da32287f42f' } ],
      B: [ { transaction_id: '25', id: '30de2023-c86f-448d-a5d8-c129d9db1175' },
           { transaction_id: '25', id: 'd4acf34d-5bb8-42fc-9b1d-55d5ef4040e6' } ],
      C: [ { transaction_id: '33282616173397531367', id: '92a8f4c6-e1a7-435a-8134-921ed1548f45' } ]
    }
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
  end

  def unsuccessful_poa_submissions
    [
      { id: '61f6d6c9-b6ac-49c7-b1df-bccd065dbf9c', created_at: 1.day.ago.to_s },
      { id: '2753f720-d0a9-4b93-9721-eb3dd67fab9b', created_at: 1.day.ago.to_s }
    ]
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
    [
      { id: '61f6d6c9-b6ac-49c7-b1df-bccd065dbf9c', created_at: 1.day.ago.to_s },
      { id: '2753f720-d0a9-4b93-9721-eb3dd67fab9b', created_at: 1.day.ago.to_s }
    ]
  end

  def itf_totals
    [
      {
        'consumer 1' => { totals: 2, submitted: 1, errored: 1 }
      },
      {
        'consumer 2' => { totals: 1, submitted: 1, errored: 0 }
      }
    ]
  end
end
