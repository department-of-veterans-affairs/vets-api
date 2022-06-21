# frozen_string_literal: true

class ClaimsApiUnsuccessfulReportMailerPreview < ActionMailer::Preview
  def build
    to = Time.zone.now
    from = Time.at(0).utc

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
      { 'GDIT' => { pending: 2,
                    errored: 1,
                    totals: 3,
                    percentage_with_flashes: '50.0%',
                    percentage_with_special_issues: '50.0%' } }
    ]
  end

  def poa_totals
    { total: 24, updated: 15, errored: 2, pending: 3, uploaded: 4 }
  end

  def unsuccessful_poa_submissions
    [
      { id: 'd9e04d01-366e-445f-809c-b2af46a226db', created_at: 7.days.ago.to_s,
        vbms_error_message: 'File could not be retrieved from AWS' },
      { id: 'b1744635-25de-4adb-b64c-37436c1e4079', created_at: 6.days.ago.to_s,
        vbms_error_message: 'File could not be retrieved from AWS' },
      { id: '69d521f9-0879-40c5-ad43-27a38e462592', created_at: 5.days.ago.to_s,
        vbms_error_message: 'An unknown error has occurred when uploading document' },
      { id: 'c313a69c-60ab-4f53-af9f-1f003f67058f', created_at: 4.days.ago.to_s,
        vbms_error_message: 'An unknown error has occurred when uploading document' }
    ]
  end
end
