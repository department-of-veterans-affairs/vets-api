# frozen_string_literal: true

class ClaimsApiSubmissionReportMailerPreview < ActionMailer::Preview
  def build
    to = Time.zone.now
    from = 1.month.ago

    ClaimsApi::SubmissionReportMailer.build(
      from,
      to,
      submissions,
      disability_claims,
      poa_claims,
      itf_claims,
      ews_claims
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

  def disability_claims
    115
  end

  def poa_claims
    23
  end

  def itf_claims
    0
  end

  def ews_claims
    2
  end
end
