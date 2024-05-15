# frozen_string_literal: true

class ClaimsApiSubmissionReportMailerPreview < ActionMailer::Preview
  def build
    to = Time.zone.now
    from = 1.month.ago

    ClaimsApi::SubmissionReportMailer.build(
      from,
      to,
      submissions,
      consumer_claims_totals: claims_totals,
      poa_totals:,
      ews_totals:,
      itf_totals:
    )
  end

  private

  def submissions
    [
      { id: 1, claim_id: '3a03bc5e-b77d-42c7-bad5-0fe3c334f852',
        claim_type: 'PACT', consumer_label: 'Claims API Smoketesting - Local',
        created_at: DateTime.now, updated_at: DateTime.now },
      { id: 2, claim_id: '87f2c86a-9773-425a-9477-adcae4011e7b',
        claim_type: 'PACT', consumer_label: 'Claims API Smoketesting - Local',
        created_at: DateTime.now,
        updated_at: DateTime.now },
      { id: 3, claim_id: 'c3527ebb-710a-4806-9339-59dc846623c9',
        claim_type: 'PACT', consumer_label: 'Claims API Smoketesting - Local - second consumer',
        created_at: DateTime.now, updated_at: DateTime.now },
      { id: 4, claim_id: '9096cd0e-0d97-4ee3-be3f-2279e47a81bc',
        claim_type: 'PACT', consumer_label: 'Claims API Smoketesting - Local - third consumer',
        created_at: DateTime.now, updated_at: DateTime.now }
    ]
  end

  def unsuccessful_claims_submissions
    [{ id: '019be853-fd70-4b65-b37b-c3f3842aaaca', status: 'errored', source: 'GDIT', created_at: 1.day.ago.to_s }]
  end

  def claims_totals
    [
      { 'consumer 1' => { pending: 2, errored: 1, totals: 3  } },
      { 'consumer 2' => { pending: 3, errored: 3, totals: 6 } }
    ]
  end

  def poa_totals
    [
      {'consumer 1' => { totals: 10, updated: 5, errored: 2, pending: 1, uploaded: 2 } },
      {'consumer 2' => { totals: 8, updated: 3, errored: 2, pending: 1, uploaded: 2 } }
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
      {'consumer 1' => { totals: 10, updated: 5, errored: 2, pending: 1, uploaded: 2 } },
      {'consumer 2' => { totals: 8, updated: 3, errored: 2, pending: 1, uploaded: 2 } }
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
      {'consumer 1' => { totals: 2, submitted: 1, errored: 1 } },
      {'consumer 2' => { totals: 1, submitted: 1, errored: 0 } }
    ]
  end
end
