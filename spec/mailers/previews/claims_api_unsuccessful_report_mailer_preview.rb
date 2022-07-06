# frozen_string_literal: true

class ClaimsApiUnsuccessfulReportMailerPreview < ActionMailer::Preview
  def build
    to = Time.zone.now
    from = 1.day.ago

    ClaimsApi::UnsuccessfulReportMailer.build(
      from,
      to,
      consumer_claims_totals: claims_totals,
      unsuccessful_claims_submissions: unsuccessful_claims_submissions,
      poa_totals: poa_totals,
      unsuccessful_poa_submissions: unsuccessful_poa_submissions
    )
  end

  private

  def unsuccessful_claims_submissions
    [
      { id: '019be853-fd70-4b65-b37b-c3f3842aaaca', status: 'errored', source: 'GDIT', created_at: 1.day.ago.to_s }
    ]
  end

  def claims_totals
    [
      { 'consumer 1' => { pending: 2,
                          errored: 1,
                          totals: 3,
                          percentage_with_flashes: '50.0%',
                          percentage_with_special_issues: '50.0%' } }
    ]
  end

  def poa_totals
    { total: 10, updated: 5, errored: 2, pending: 1, uploaded: 2 }
  end

  def unsuccessful_poa_submissions
    [
      { id: 'b1744635-25de-4adb-b64c-37436c1e4079', created_at: 1.day.ago.to_s,
        vbms_error_message: 'File could not be retrieved from AWS' },
      { id: '69d521f9-0879-40c5-ad43-27a38e462592', created_at: 1.day.ago.to_s,
        vbms_error_message: 'An unknown error has occurred when uploading document' }
    ]
  end
end
